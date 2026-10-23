const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const [NODE_MAJOR, NODE_MINOR] = process.versions.node.split('.').map(Number);
if (NODE_MAJOR < 22 || (NODE_MAJOR === 22 && NODE_MINOR < 5)) {
  console.error('需要 Node.js 22.5 或更高版本（推荐 Node.js 24+）。当前版本：' + process.versions.node);
  process.exit(1);
}
const { DatabaseSync } = require('node:sqlite');

const ROOT = path.resolve(__dirname, '..');
const DATA = path.join(ROOT, 'data');
const PUBLIC = path.join(ROOT, 'public');
const DB_PATH = path.join(DATA, 'wardrobe.db');
const ORIGINAL = path.join(DATA, 'images', 'original');
const THUMBS = path.join(DATA, 'images', 'thumbs');
const TRASH = path.join(DATA, 'trash');
for (const dir of [DATA, ORIGINAL, THUMBS, TRASH]) fs.mkdirSync(dir, { recursive: true });

const db = new DatabaseSync(DB_PATH);
db.exec(`PRAGMA journal_mode = WAL;
CREATE TABLE IF NOT EXISTS items (
 id TEXT PRIMARY KEY,
 name TEXT NOT NULL DEFAULT '',
 category TEXT NOT NULL DEFAULT '待分类',
 subcategory TEXT NOT NULL DEFAULT '',
 color TEXT NOT NULL DEFAULT '',
 size TEXT NOT NULL DEFAULT '',
 thickness TEXT NOT NULL DEFAULT '',
 fit TEXT NOT NULL DEFAULT '',
 notes TEXT NOT NULL DEFAULT '',
 status TEXT NOT NULL DEFAULT 'active',
 created_at TEXT NOT NULL,
 updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS photos (
 id TEXT PRIMARY KEY,
 item_id TEXT NOT NULL REFERENCES items(id),
 original_path TEXT NOT NULL,
 thumbnail_path TEXT NOT NULL,
 original_filename TEXT NOT NULL,
 source TEXT NOT NULL DEFAULT '其他',
 sort_order INTEGER NOT NULL DEFAULT 0,
 created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS photos_item_idx ON photos(item_id);`);
const photoColumns = db.prepare('PRAGMA table_info(photos)').all().map(x => x.name);
if (!photoColumns.includes('source')) db.exec("ALTER TABLE photos ADD COLUMN source TEXT NOT NULL DEFAULT '其他'");
if (!photoColumns.includes('sort_order')) db.exec("ALTER TABLE photos ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0");

function now() { return new Date().toISOString(); }
function id(prefix) { return `${prefix}-${crypto.randomUUID().slice(0, 8)}`; }
function itemCode() {
  const day = new Date().toISOString().slice(0, 10).replaceAll('-', '');
  const ids = db.prepare('SELECT id FROM items').all().map(row => String(row.id));
  const highest = ids.reduce((max, value) => {
    const match = value.match(/-(\d{4,})$/);
    return match ? Math.max(max, Number(match[1])) : max;
  }, 0);
  return `CLO-${day}-${String(highest + 1).padStart(4, '0')}`;
}
function safeName(name) {
  const ext = path.extname(name || '').toLowerCase().replace(/[^a-z0-9.]/g, '');
  const allowed = ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.heic', '.avif'];
  return allowed.includes(ext) ? ext : '.bin';
}
function cleanFilename(name) { return String(name || '照片').replace(/[\\/:*?"<>|\x00-\x1f]/g, '_').slice(0, 160); }
function publicItem(row) {
  const photos = db.prepare('SELECT * FROM photos WHERE item_id = ? ORDER BY sort_order ASC, created_at ASC').all(row.id).map(p => ({
    id: p.id, originalPath: p.original_path, thumbnailPath: p.thumbnail_path, originalFilename: p.original_filename, source: p.source || '其他',
    sortOrder: p.sort_order || 0,
    url: `/files/${p.original_path.replaceAll('\\', '/')}`,
    thumbUrl: `/files/${p.thumbnail_path.replaceAll('\\', '/')}`
  }));
  return { ...row, photos };
}
function listItems(includeTrash = false) {
  const rows = db.prepare(`SELECT * FROM items WHERE status = ? ORDER BY updated_at DESC`).all(includeTrash ? 'trash' : 'active');
  return rows.map(publicItem);
}
function exportJson() {
  const items = listItems(false).map(x => ({
    id: x.id, name: x.name, category: x.category, subcategory: x.subcategory,
    color: x.color, size: x.size, thickness: x.thickness, fit: x.fit, notes: x.notes,
    photos: x.photos.map(p => ({ path: p.originalPath.replaceAll('\\', '/'), source: p.source || '其他' })),
    updated_at: x.updated_at
  }));
  fs.writeFileSync(path.join(DATA, 'wardrobe.json'), JSON.stringify({ version: 1, generated_at: now(), items }, null, 2), 'utf8');
}
function json(res, status, data) { const body = JSON.stringify(data); res.writeHead(status, {'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'}); res.end(body); }
function parseBody(req) { return new Promise((resolve, reject) => { const chunks=[]; req.on('data', c=>chunks.push(c)); req.on('end',()=>resolve(Buffer.concat(chunks))); req.on('error', reject); }); }
function parseMultipart(buffer, contentType) {
  const match = /boundary=(?:"([^"]+)"|([^;]+))/i.exec(contentType || '');
  if (!match) return [];
  const boundary = Buffer.from(`--${match[1] || match[2]}`); const parts=[]; let start=0;
  while (true) { const a=buffer.indexOf(boundary,start); if(a<0) break; const b=buffer.indexOf(boundary,a+boundary.length); if(b<0) break; const raw=buffer.slice(a+boundary.length+2,b-2); start=b; const sep=raw.indexOf('\r\n\r\n'); if(sep<0) continue;
    const headers=raw.slice(0,sep).toString('utf8'); const body=raw.slice(sep+4); const cd=/Content-Disposition:.*?name="([^"]+)"(?:; filename="([^"]*)")?/i.exec(headers); if(!cd) continue;
    parts.push({name:cd[1], filename:cd[2] || '', data:body});
  } return parts;
}
function serveFile(res, filePath) { if (!fs.existsSync(filePath) || !fs.statSync(filePath).isFile()) return json(res,404,{error:'文件不存在'}); const ext=path.extname(filePath).toLowerCase(); const types={'.html':'text/html; charset=utf-8','.js':'application/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.json':'application/json; charset=utf-8','.jpg':'image/jpeg','.jpeg':'image/jpeg','.png':'image/png','.webp':'image/webp','.gif':'image/gif','.avif':'image/avif'}; res.writeHead(200,{'Content-Type':types[ext]||'application/octet-stream','Cache-Control': ['.html','.js','.css'].includes(ext) ? 'no-store' : 'public, max-age=3600'}); fs.createReadStream(filePath).pipe(res); }
function findItem(id) { return db.prepare('SELECT * FROM items WHERE id = ?').get(id); }

const server = http.createServer(async (req,res) => {
  try {
    const u = new URL(req.url, 'http://localhost'); const method=req.method; const pathname=u.pathname;
    if (method==='GET' && pathname==='/api/health') return json(res,200,{ok:true,service:'wardrobe-local',version:'0.2.0'});
    if (method==='GET' && (pathname==='/api/items' || pathname==='/api/wardrobe')) return json(res,200,{items:listItems(false), trash:listItems(true)});
    if (method==='GET' && pathname==='/api/export') { exportJson(); return json(res,200,{ok:true,path:'data/wardrobe.json'}); }
    if (method==='POST' && pathname==='/api/items') {
      const payload=JSON.parse((await parseBody(req)).toString('utf8')||'{}'); const t=now(); const item={id:itemCode(),name:String(payload.name||'').trim(),category:payload.category||'待分类',subcategory:payload.subcategory||'',color:payload.color||'',size:payload.size||'',thickness:payload.thickness||'',fit:payload.fit||'',notes:payload.notes||'',status:'active',created_at:t,updated_at:t};
      db.prepare('INSERT INTO items (id,name,category,subcategory,color,size,thickness,fit,notes,status,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)').run(...Object.values(item)); exportJson(); return json(res,201,{item:publicItem(item)});
    }
    const itemMatch=pathname.match(/^\/api\/items\/([^/]+)$/);
    if (itemMatch && method==='PATCH') { const idv=decodeURIComponent(itemMatch[1]); const old=findItem(idv); if(!old) return json(res,404,{error:'单品不存在'}); const p=JSON.parse((await parseBody(req)).toString('utf8')||'{}'); const allowed=['name','category','subcategory','color','size','thickness','fit','notes']; const next={}; for(const k of allowed) next[k]=p[k]===undefined?old[k]:String(p[k]||''); next.updated_at=now(); db.prepare('UPDATE items SET name=?,category=?,subcategory=?,color=?,size=?,thickness=?,fit=?,notes=?,updated_at=? WHERE id=?').run(next.name,next.category,next.subcategory,next.color,next.size,next.thickness,next.fit,next.notes,next.updated_at,idv); exportJson(); return json(res,200,{item:publicItem(findItem(idv))}); }
    if (itemMatch && method==='DELETE') { const idv=decodeURIComponent(itemMatch[1]); if(!findItem(idv)) return json(res,404,{error:'单品不存在'}); db.prepare("UPDATE items SET status='trash', updated_at=? WHERE id=?").run(now(),idv); exportJson(); return json(res,200,{ok:true}); }
    const permanentItemMatch=pathname.match(/^\/api\/trash\/items\/([^/]+)$/);
    if (permanentItemMatch && method==='DELETE') { const idv=decodeURIComponent(permanentItemMatch[1]); const row=findItem(idv); if(!row) return json(res,404,{error:'单品不存在'}); const photos=db.prepare('SELECT original_path,thumbnail_path FROM photos WHERE item_id=?').all(idv); for(const ph of photos){for(const rel of [ph.original_path,ph.thumbnail_path]){const file=path.join(DATA,rel); if(fs.existsSync(file))fs.rmSync(file,{force:true});}} db.prepare('DELETE FROM photos WHERE item_id=?').run(idv); db.prepare('DELETE FROM items WHERE id=?').run(idv); exportJson(); return json(res,200,{ok:true}); }
    const restoreMatch=pathname.match(/^\/api\/items\/([^/]+)\/restore$/);
    if (restoreMatch && method==='POST') { const idv=decodeURIComponent(restoreMatch[1]); db.prepare("UPDATE items SET status='active', updated_at=? WHERE id=?").run(now(),idv); exportJson(); return json(res,200,{item:publicItem(findItem(idv))}); }
    const photoMatch=pathname.match(/^\/api\/items\/([^/]+)\/photos$/);
    if (photoMatch && method==='POST') { const idv=decodeURIComponent(photoMatch[1]); if(!findItem(idv)) return json(res,404,{error:'单品不存在'}); const parts=parseMultipart(await parseBody(req),req.headers['content-type']); const files=parts.filter(x=>x.filename); const source=String((parts.find(x=>x.name==='source')||{}).data?.toString('utf8')||'其他'); const added=[]; for(const f of files){const ext=safeName(f.filename); const pid=id('PHT'); const base=`${idv}-${pid}${ext}`; const rel=path.join('images','original',base); const thumbRel=path.join('images','thumbs',base); fs.writeFileSync(path.join(DATA,rel),f.data); fs.copyFileSync(path.join(DATA,rel),path.join(DATA,thumbRel)); const t=now(); db.prepare('INSERT INTO photos (id,item_id,original_path,thumbnail_path,original_filename,source,created_at) VALUES (?,?,?,?,?,?,?)').run(pid,idv,rel,thumbRel,cleanFilename(f.filename),source,t); added.push(pid); }
      db.prepare('UPDATE items SET updated_at=? WHERE id=?').run(now(),idv); exportJson(); return json(res,201,{added}); }
    if (method==='POST' && pathname==='/api/upload') {
      const parts=parseMultipart(await parseBody(req),req.headers['content-type']); const target=(parts.find(x=>x.name==='itemId')||{}).data?.toString('utf8')||''; const files=parts.filter(x=>x.name==='files' && x.filename); if(!files.length) return json(res,400,{error:'没有收到图片'}); const field=n=>String((parts.find(x=>x.name===n)||{}).data?.toString('utf8')||''); let targetId=target && findItem(target) ? target : '';
      if(!targetId){const t=now(); targetId=itemCode(); db.prepare('INSERT INTO items (id,name,category,subcategory,color,size,thickness,fit,notes,status,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)').run(targetId,field('name'),field('category')||'待分类','',field('color'),'','','',field('notes'),'active',t,t);}
      const source=field('source')||'其他'; for(const f of files){const ext=safeName(f.filename); const pid=id('PHT'); const base=`${targetId}-${pid}${ext}`; const rel=path.join('images','original',base); const thumbRel=path.join('images','thumbs',base); fs.writeFileSync(path.join(DATA,rel),f.data); fs.copyFileSync(path.join(DATA,rel),path.join(DATA,thumbRel)); db.prepare('INSERT INTO photos (id,item_id,original_path,thumbnail_path,original_filename,source,created_at) VALUES (?,?,?,?,?,?,?)').run(pid,targetId,rel,thumbRel,cleanFilename(f.filename),source,now());}
      db.prepare('UPDATE items SET updated_at=? WHERE id=?').run(now(),targetId); exportJson(); return json(res,201,{items:listItems(false),created:[targetId]});
    }
    const photoApiMatch=pathname.match(/^\/api\/photos\/([^/]+)$/);
    const photoOrderMatch=pathname.match(/^\/api\/items\/([^/]+)\/photos\/order$/);
    if(photoOrderMatch && method==='PUT'){const idv=decodeURIComponent(photoOrderMatch[1]); const p=JSON.parse((await parseBody(req)).toString('utf8')||'{}'); const ids=Array.isArray(p.photoIds)?p.photoIds:[]; const update=db.prepare('UPDATE photos SET sort_order=? WHERE id=? AND item_id=?'); ids.forEach((pid,i)=>update.run(i,pid,idv)); db.prepare('UPDATE items SET updated_at=? WHERE id=?').run(now(),idv); exportJson(); return json(res,200,{item:publicItem(findItem(idv))});}
    if(photoApiMatch && method==='PATCH'){const pid=decodeURIComponent(photoApiMatch[1]); const p=JSON.parse((await parseBody(req)).toString('utf8')||'{}'); db.prepare('UPDATE photos SET source=? WHERE id=?').run(String(p.source||'其他'),pid); const ph=db.prepare('SELECT * FROM photos WHERE id=?').get(pid); if(!ph)return json(res,404,{error:'照片不存在'}); exportJson(); return json(res,200,{photo:ph});}
    if(photoApiMatch && method==='DELETE'){const pid=decodeURIComponent(photoApiMatch[1]); const ph=db.prepare('SELECT * FROM photos WHERE id=?').get(pid); if(!ph)return json(res,404,{error:'照片不存在'}); const trashDir=path.join(TRASH,'photos'); fs.mkdirSync(trashDir,{recursive:true}); for(const rel of [ph.original_path,ph.thumbnail_path]){const src=path.join(DATA,rel); if(fs.existsSync(src))fs.renameSync(src,path.join(trashDir,path.basename(src)));} db.prepare('DELETE FROM photos WHERE id=?').run(pid); exportJson(); return json(res,200,{ok:true});}
    if (method==='GET' && pathname.startsWith('/files/')) { const rel=decodeURIComponent(pathname.slice(7)); const full=path.resolve(DATA,rel); if(!full.startsWith(DATA)) return json(res,403,{error:'禁止访问'}); return serveFile(res,full); }
    if (method==='GET') { const rel=pathname==='/'?'index.html':pathname.slice(1); const full=path.resolve(PUBLIC,rel); if(!full.startsWith(PUBLIC)) return json(res,403,{error:'禁止访问'}); return serveFile(res,full); }
    json(res,404,{error:'未找到'});
  } catch (e) { console.error(e); json(res,500,{error:e.message||'服务器错误'}); }
});

exportJson();
const port=Number(process.env.PORT||4173); const host=process.env.HOST||'127.0.0.1'; server.listen(port,host,()=>console.log(`衣橱工具已启动：http://${host}:${port}`));
