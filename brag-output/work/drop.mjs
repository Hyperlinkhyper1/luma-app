import { execFileSync } from 'child_process';
const FF = process.env.APPDATA + '/com.luma/luma/tools/ffmpeg.exe', SR = 22050;
const raw = execFileSync(FF, ['-v','error','-ss','50','-t','25','-i',process.argv[2],'-ac','1','-ar',String(SR),'-f','f32le','-'],{maxBuffer:1<<30});
const x = new Float32Array(raw.buffer, raw.byteOffset, raw.length/4);
const B = 60/105, first = 0.302;
let lp=0; const lo=new Float32Array(x.length); for(let i=0;i<x.length;i++){lp+=0.01*(x[i]-lp);lo[i]=lp;}
let out=[];
for(let k=Math.ceil((50-first)/B); first+k*B<74; k++){ const t=first+k*B, s=Math.round((t-50)*SR); let e=0,f=0; for(let i=s;i<s+SR*0.12;i++){e+=lo[i]*lo[i];f+=x[i]*x[i];} out.push(`${t.toFixed(3)} k=${k} k%4=${k%4} low=${(10*Math.log10(e+1e-9)).toFixed(1)} full=${(10*Math.log10(f+1e-9)).toFixed(1)}`); }
console.log(out.join('\n'));
