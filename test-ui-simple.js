import puppeteer from 'puppeteer';
import fs from 'fs';

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
  
  // Take screenshot of home
  await page.screenshot({ path: '/tmp/workout-home.png' });
  console.log('📸 Screenshot 1: Home page saved\n');
  
  // Click "+ New Program" button
  console.log('📋 Clicking "+ New Program"...');
  await page.evaluate(() => {
    const btn = Array.from(document.querySelectorAll('button')).find(b => b.textContent.includes('New Program'));
    if (btn) btn.click();
  });
  await new Promise(r => setTimeout(r,(800);
  
  // Take screenshot of modal
  await page.screenshot({ path: '/tmp/workout-import-modal.png' });
  console.log('📸 Screenshot 2: Import modal saved\n');
  
  // Select JSON tab
  console.log('📝 Selecting JSON...');
  await page.evaluate(() => {
    const btn = Array.from(document.querySelectorAll('button')).find(b => b.textContent.trim() === 'JSON');
    if (btn) btn.click();
  });
  await new Promise(r => setTimeout(r,(300);
  
  // Import JSON
  console.log('📥 Importing program...');
  const programJSON = fs.readFileSync('/home/dexter/.openclaw/media/inbound/file_9---3fb78401-1af0-4fbf-b841-be9b94b5654a.json', 'utf8');
  
  await page.evaluate((json) => {
    const textarea = document.querySelector('textarea');
    if (textarea) {
      textarea.value = json;
      textarea.dispatchEvent(new Event('input', { bubbles: true }));
    }
  }, programJSON);
  
  await new Promise(r => setTimeout(r,(300);
  
  // Click Import
  await page.evaluate(() => {
    const btn = Array.from(document.querySelectorAll('button')).find(b => b.textContent.includes('Import') && !b.textContent.includes('modal'));
    if (btn) btn.click();
  });
  
  await new Promise(r => setTimeout(r,(1500);
  
  // Check program imported
  const programName = await page.evaluate(() => {
    const h3 = document.querySelector('.card h3');
    return h3 ? h3.textContent : null;
  });
  console.log(`✅ Program imported: ${programName}\n`);
  
  // Take screenshot
  await page.screenshot({ path: '/tmp/workout-programs.png' });
  console.log('📸 Screenshot 3: Programs list saved\n');
  
  // Open program
  console.log('🏋️ Opening program...');
  await page.evaluate(() => {
    const card = document.querySelector('.card');
    if (card) card.click();
  });
  await new Promise(r => setTimeout(r,(800);
  
  // Start workout
  console.log('▶️ Starting Day A...');
  await page.evaluate(() => {
    const btn = Array.from(document.querySelectorAll('button')).find(b => b.textContent.includes('Start Workout'));
    if (btn) btn.click();
  });
  await new Promise(r => setTimeout(r,(1500);
  
  // Take screenshot
  await page.screenshot({ path: '/tmp/workout-active.png' });
  console.log('📸 Screenshot 4: Active workout saved\n');
  
  // Open "+ Add Set" modal
  console.log('➕ Opening set modal...');
  await page.evaluate(() => {
    const btn = Array.from(document.querySelectorAll('button')).find(b => b.textContent.includes('Add Set'));
    if (btn) btn.click();
  });
  await new Promise(r => setTimeout(r,(800);
  
  // Take screenshot of modal
  await page.screenshot({ path: '/tmp/workout-set-modal.png' });
  console.log('📸 Screenshot 5: Set logging modal saved\n');
  
  // Check buttons
  const buttonInfo = await page.evaluate(() => {
    const buttons = Array.from(document.querySelectorAll('button[type="button"]'));
    return buttons.map(btn => ({
      text: btn.textContent.trim(),
      hasRed: btn.className.includes('red-600'),
      hasBorder: btn.className.includes('border-2')
    }));
  });
  
  console.log('🔘 Button analysis:');
  buttonInfo.forEach(btn => {
    if (btn.text === '−' || btn.text === '+') {
      console.log(`  ${btn.text}: ${btn.hasRed ? '✅ Red' : '❌ No red'} | ${btn.hasBorder ? '✅ Border' : '❌ No border'}`);
    }
  });
  
  // Test increment
  console.log('\n🧪 Testing increment button...');
  await page.evaluate(() => {
    const plusBtn = Array.from(document.querySelectorAll('button')).find(b => b.textContent.trim() === '+');
    if (plusBtn) plusBtn.click();
  });
  await new Promise(r => setTimeout(r,(300);
  
  const weightValue = await page.evaluate(() => {
    const input = document.querySelector('input[inputmode="decimal"]');
    return input ? input.value : null;
  });
  console.log(`  Weight value after click: ${weightValue}`);
  
  // Final screenshot
  await page.screenshot({ path: '/tmp/workout-set-modal-after.png' });
  console.log('📸 Screenshot 6: After increment saved\n');
  
  console.log('✅ Test complete!');
  console.log('\n📁 Screenshots saved to:');
  console.log('  /tmp/workout-*.png');
  
  await browser.close();
})();
