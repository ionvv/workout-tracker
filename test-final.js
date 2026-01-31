import puppeteer from 'puppeteer';
import fs from 'fs';

const sleep = (ms) => new Promise(r => setTimeout(r, ms));

(async () => {
  console.log('🚀 Starting UI test...\n');
  
  const browser = await puppeteer.launch({
    headless: true,
    executablePath: '/usr/bin/chromium-browser',
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage']
  });
  
  const page = await browser.newPage();
  await page.setViewport({ width: 375, height: 812 });
  
  // Load app
  console.log('📱 Loading app...');
  await page.goto('https://workout-tracker-963.pages.dev/', { waitUntil: 'networkidle0' });
  console.log(`✅ Page loaded: ${await page.title()}\n`);
  await page.screenshot({ path: '/tmp/workout-1-home.png' });
  
  // Click "+ New Program"
  console.log('📋 Opening import modal...');
  await page.evaluate(() => {
    const btn = Array.from(document.querySelectorAll('button')).find(b => b.textContent.includes('New Program'));
    if (btn) btn.click();
  });
  await sleep(800);
  await page.screenshot({ path: '/tmp/workout-2-modal.png' });
  
  // Select JSON
  console.log('📝 Selecting JSON...');
  await page.evaluate(() => {
    const btn = Array.from(document.querySelectorAll('button')).find(b => b.textContent.trim() === 'JSON');
    if (btn) btn.click();
  });
  await sleep(300);
  
  // Import program
  console.log('📥 Importing program...');
  const programJSON = fs.readFileSync('/home/dexter/.openclaw/media/inbound/file_9---3fb78401-1af0-4fbf-b841-be9b94b5654a.json', 'utf8');
  await page.evaluate((json) => {
    const textarea = document.querySelector('textarea');
    if (textarea) {
      textarea.value = json;
      textarea.dispatchEvent(new Event('input', { bubbles: true }));
    }
  }, programJSON);
  await sleep(300);
  
  await page.evaluate(() => {
    const btn = Array.from(document.querySelectorAll('button')).find(b => b.textContent.includes('Import') && !b.textContent.includes('modal'));
    if (btn) btn.click();
  });
  await sleep(1500);
  
  const programName = await page.evaluate(() => document.querySelector('.card h3')?.textContent);
  console.log(`✅ Program imported: ${programName}\n`);
  await page.screenshot({ path: '/tmp/workout-3-programs.png' });
  
  // Open program
  console.log('🏋️ Opening program...');
  await page.evaluate(() => document.querySelector('.card')?.click());
  await sleep(800);
  
  // Start workout
  console.log('▶️ Starting Day A...');
  await page.evaluate(() => {
    const btn = Array.from(document.querySelectorAll('button')).find(b => b.textContent.includes('Start Workout'));
    if (btn) btn.click();
  });
  await sleep(1500);
  await page.screenshot({ path: '/tmp/workout-4-active.png' });
  
  // Open set modal
  console.log('➕ Opening set modal...');
  await page.evaluate(() => {
    const btn = Array.from(document.querySelectorAll('button')).find(b => b.textContent.includes('Add Set'));
    if (btn) btn.click();
  });
  await sleep(800);
  await page.screenshot({ path: '/tmp/workout-5-set-modal.png' });
  
  // Check buttons
  const buttonInfo = await page.evaluate(() => {
    const buttons = Array.from(document.querySelectorAll('button[type="button"]'));
    return buttons.map(btn => ({
      text: btn.textContent.trim(),
      hasRed: btn.className.includes('red-600'),
      hasBorder: btn.className.includes('border-2'),
      width: btn.offsetWidth,
      height: btn.offsetHeight
    }));
  });
  
  console.log('\n🔘 Button test results:');
  const plusMinus = buttonInfo.filter(b => b.text === '−' || b.text === '+');
  plusMinus.forEach(btn => {
    console.log(`  ${btn.text}: ${btn.hasRed ? '✅' : '❌'} Red | ${btn.hasBorder ? '✅' : '❌'} Border | ${btn.width}×${btn.height}px`);
  });
  
  // Test increment
  console.log('\n🧪 Testing increment...');
  await page.evaluate(() => {
    const plusBtn = Array.from(document.querySelectorAll('button')).find(b => b.textContent.trim() === '+');
    if (plusBtn) plusBtn.click();
  });
  await sleep(300);
  
  const weightValue = await page.evaluate(() => document.querySelector('input[inputmode="decimal"]')?.value);
  console.log(`  Weight after increment: ${weightValue || '(empty)'}`);
  
  await page.screenshot({ path: '/tmp/workout-6-after-increment.png' });
  
  console.log('\n✅ Test complete!\n');
  console.log('📁 Screenshots:');
  console.log('  /tmp/workout-*.png');
  
  await browser.close();
})();
