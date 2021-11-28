import sys
import time
import json
from selenium import webdriver

# See:
# https://stackoverflow.com/questions/46656622/transparent-screenshot-with-headless-chromedriver-via-selenium
def send(cmd, params={}):
  resource = "/session/%s/chromium/send_command_and_get_result" % driver.session_id
  url = driver.command_executor._url + resource
  body = json.dumps({'cmd':cmd, 'params': params})
  driver.command_executor._request('POST', url, body)


options = webdriver.ChromeOptions()
options.add_argument("disable-gpu")
options.add_argument("disable-infobars")
options.add_argument('headless')

driver = webdriver.Chrome(options=options)
driver.implicitly_wait(3)
send("Emulation.setDefaultBackgroundColorOverride", {'color': {'r': 0, 'g': 0, 'b': 0, 'a': 0}})
try:
  while True:
    html_path = input()
    base_path = input()
    js_text = ''
    for line in sys.stdin:
      if '' == line.strip():
        break
      js_text += line


    driver.set_window_size(1920, 1080)
    driver.get(html_path)
    pieces = driver.execute_script('return pieces;');

    driver.execute_script('init_template();')
    driver.execute_script(js_text)

    for p in pieces:
      driver.execute_script(f'foreground_only("{p}");')
      driver.get_screenshot_as_file(f'{base_path}_fg_{p}.png')
      print(f'fg_{p} {base_path}_fg_{p}.png')

      driver.execute_script(f'background_only("{p}");')
      driver.get_screenshot_as_file(f'{base_path}_bg_{p}.png')
      print(f'bg_{p} {base_path}_bg_{p}.png')
    print('', flush=True)
finally:
  driver.close()
  driver.quit()

