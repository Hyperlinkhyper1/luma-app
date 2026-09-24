import puppeteer from 'puppeteer-core';
const b = await puppeteer.launch({ executablePath: 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\153.0.4234.48\\msedge.exe', headless: true, pipe: true, args: ['--no-sandbox'] }).catch(e => { console.log('pipe fail', e.message); return null; });
if (b) { console.log('pipe ok', await b.version()); await b.close(); }
