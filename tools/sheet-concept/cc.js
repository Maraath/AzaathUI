const I=require('./img');const c=I.readBMP('concept.bmp');
const W=c.w,H=c.h,th=+process.argv[2]||90;
const L=new Float32Array(W*H);for(let i=0;i<W*H;i++)L[i]=0.3*c.px[i*4]+0.59*c.px[i*4+1]+0.11*c.px[i*4+2];
const m=new Uint8Array(W*H);for(let i=0;i<W*H;i++)m[i]=L[i]>th?1:0;
// dilate horizontally by 4 to merge glyphs into words/lines
const d=new Uint8Array(W*H);const R=+process.argv[3]||5;
for(let y=0;y<H;y++)for(let x=0;x<W;x++)if(m[y*W+x])for(let k=-R;k<=R;k++){const xx=x+k;if(xx>=0&&xx<W)d[y*W+xx]=1;}
const lab=new Int32Array(W*H);let n=0;const boxes=[];
for(let i=0;i<W*H;i++)if(d[i]&&!lab[i]){n++;const st=[i];lab[i]=n;let b={x0:1e9,y0:1e9,x1:0,y1:0,c:0};
 while(st.length){const p=st.pop();const x=p%W,y=(p-x)/W;if(m[p])b.c++;b.x0=Math.min(b.x0,x);b.x1=Math.max(b.x1,x);b.y0=Math.min(b.y0,y);b.y1=Math.max(b.y1,y);
  for(const q of [p-1,p+1,p-W,p+W])if(q>=0&&q<W*H&&d[q]&&!lab[q]){lab[q]=n;st.push(q);}}
 if(b.c>8&&b.x0>55&&b.x1<715)boxes.push(b);}
boxes.sort((a,b)=>a.y0-b.y0||a.x0-b.x0);
for(const b of boxes)console.log(`x ${b.x0+R}-${b.x1-R} y ${b.y0}-${b.y1} w${b.x1-b.x0-2*R+1} h${b.y1-b.y0+1} n${b.c}`);
