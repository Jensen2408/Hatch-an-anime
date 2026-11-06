// Original coarse-grid animated hull wakes and outline-free splash art.
const fs=require('fs'),path=require('path'),z=require('zlib'),http=require('http');
const out=path.resolve(__dirname,'../../assets/water/Wakes');
function chunk(t,d){const n=Buffer.alloc(4),c=Buffer.alloc(4),b=Buffer.concat([Buffer.from(t),d]);n.writeUInt32BE(d.length);c.writeUInt32BE(z.crc32(b)>>>0);return Buffer.concat([n,b,c])}
function png(name,w,h,p){const raw=Buffer.alloc(h*(w*4+1));for(let y=0;y<h;y++)p.copy(raw,y*(w*4+1)+1,y*w*4,(y+1)*w*4);const hd=Buffer.alloc(13);hd.writeUInt32BE(w);hd.writeUInt32BE(h,4);hd[8]=8;hd[9]=6;fs.writeFileSync(path.join(out,name),Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',hd),chunk('IDAT',z.deflateSync(raw)),chunk('IEND',Buffer.alloc(0))]))}
const hash=(x,y)=>{let v=Math.sin(x*127.1+y*311.7)*43758.5453;return v-Math.floor(v)};

for(const kind of ['egg_static','player_static','impact_new']){
 const W=48,H=kind==='impact_new'?48:72,S=4,p=Buffer.alloc(W*S*H*S*4);
 for(let y=0;y<H;y++)for(let x=0;x<W;x++){
 const u=(x+.5-W/2)/(W/2),t=(y+.5)/H,g=hash(x,y);let a=0,c=[244,254,255];
 if(kind==='impact_new'){
 const dx=x-23.5,dy=y-23.5,r=Math.hypot(dx,dy),ang=Math.atan2(dy,dx);
 const outer=18+Math.sin(ang*12)*.8;
 if(Math.abs(r-outer)<1.05)a=.96;
 if(r>12.5&&r<14&&Math.sin(ang*5)>.1)a=.5;
 if(r>20&&r<22&&g>.88)a=.75;
 }else{
 const wing=kind==='egg_static'? .42+.39*t:.30+.43*t;
 const edge=Math.abs(Math.abs(u)-wing);
 const tail=Math.min(1,(1-t)*3),head=Math.min(1,t*14);
 if(edge<.06&&g>.12)a=.92*tail*head;
 if(edge<.13&&g>.76)a=.65*tail*head;
 const band=(t-Math.abs(u)*.32+1)% .24;
 if(t>.35&&Math.abs(u)<wing-.10&&band<.035&&g>.24)a=.58*tail;
 if(g<.4)c=[188,238,251];
 }
 for(let j=0;j<S;j++)for(let i=0;i<S;i++){const k=((y*S+j)*W*S+x*S+i)*4;p[k]=c[0];p[k+1]=c[1];p[k+2]=c[2];p[k+3]=Math.round(a*255)}
 }
 png(kind+'.png',W*S,H*S,p);
}
http.createServer((req,res)=>{const n=req.url.slice(1);if(!['egg_static.png','player_static.png','impact_new.png'].includes(n)){res.writeHead(404);return res.end()}res.writeHead(200,{'Content-Type':'image/png'});res.end(fs.readFileSync(path.join(out,n)))}).listen(8099,'127.0.0.1',()=>console.log('Static wakes ready'));
