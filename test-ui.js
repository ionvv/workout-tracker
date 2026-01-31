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
  await page.setViewport({ width: 375, height: 812 }); // iPhone size
  
  // 1. Load the app
  console.log('📱 Loading app...');
  await page.goto('https://workout-tracker-963.pages.dev/', { waitUntil: 'networkidle0' });
  
  const title = await page.title();
  console.log(`✅ Page loaded: ${title}\n`);
  
  // 2. Click "+ New Program"
  console.log('📋 Opening import modal...');
  await page.waitForSelector('.btn-primary', { timeout: 5000 });
  const newProgramBtn = await page.$x("//button[contains(text(), 'New Program')]");
  if (newProgramBtn.length > 0) {
    await newProgramBtn[0].click();
  }
  await page.waitForTimeout(500);
  
  // 3. Select JSON tab
  console.log('📝 Selecting JSON import...');
  const jsonButton = await page.$x("//button[contains(., 'JSON')]");
  if (jsonButton.length > 0) {
    await jsonButton[0].click();
    await page.waitForTimeout(300);
  }
  
  // 4. Import program
  console.log('📥 Importing program...');
  const programJSON = fs.readFileSync('/home/dexter/.openclaw/media/inbound/file_9---3fb78401-1af0-4fbf-b841-be9b94b5654a.json', 'utf8');
  
  await page.evaluate((json) => {
    const textarea = document.querySelector('textarea');
    if (textarea) {
      textarea.value = json;
      textarea.dispatchEvent(new Event('input', { bubbles: true }));
    }
  }, programJSON);
  
  await page.waitForTimeout(500);
  const importBtn = await page.$x("//button[contains(text(), 'Import')]");
  if (importBtn.length > 0) {
    await importBtn[0].click();
  }
  await page.waitForTimeout(1000);
  
  // 5. Check if program appears
  const programName = await page.$eval('.card h3', el => el.textContent).catch(() => null);
  console.log(`✅ Program imported: ${programName}\n`);
  
  // 6. Open program and start workout
  console.log('🏋️ Starting workout...');
  await page.click('.card');
  await page.waitForTimeout(500);
  
  const startBtn = await page.$x("//button[contains(text(), 'Start Workout')]");
  if (startBtn.length > 0) {
    await startBtn[0].click();
  }
  await page.waitForTimeout(1000);
  
  // 7. Click "+ Add Set" to open modal
  console.log('➕ Opening set modal...');
  const addSetBtn = await page.$x("//button[contains(text(), 'Add Set')]");
  if (addSetBtn.length > 0) {
    await addSetBtn[0].click();
  }
  await page.waitForTimeout(500);
  
  // 8. Take screenshot of the modal
  console.log('📸 Taking screenshot...');
  await page.screenshot({ path: '/tmp/workout-modal.png', fullPage: false });
  
  // 9. Check for buttons
  const buttons = await page.$$eval('button[type="button"]', els => 
    els.map(el => ({
      text: el.textContent.trim(),
      classes: el.className
    }))
  );
  
  console.log('\n🔘 Found buttons:');
  buttons.forEach(btn => {
    if (btn.text === '−' || btn.text === '+') {
      console.log(`  ${btn.text} button: ${btn.classes.includes('text-red-600') ? '✅ Red styling' : '❌ Missing red'}`);
    }
  });
  
  // 10. Test increment button
  console.log('\n🧪 Testing increment button...');
  const plusButtons = await page.$x("//button[contains(text(), '+')]");
  if (plusButtons.length > 0) {
    await plusButtons[0].click();
    await page.waitForTimeout(200);
    const weightValue = await page.$eval('input[inputmode="decimal"]', el => el.value);
    console.log(`  Weight after increment: ${weightValue}`);
  }
  
  console.log('\n✅ Test complete! Screenshot saved to /tmp/workout-modal.png');
  
  await browser.close();
})();
