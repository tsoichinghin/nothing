import pyautogui
import pytesseract
import time
time.sleep(5)
screenshot = image = data = target_word = word_index = word_x = word_y = None
min_x, max_x = 0, 1919
min_y, max_y = 0, 1079
width = max_x - min_x
height = max_y - min_y
screenshot = pyautogui.screenshot(region=(min_x, min_y, width, height))
image = screenshot.convert('L')
data = pytesseract.image_to_data(image, output_type=pytesseract.Output.DICT)
print("Text on screenshot:", data)
target_word = "extension"
if target_word in data['text']:
    print("It found Add Extension")
    word_index = data['text'].index(target_word)
    word_x = data['left'][word_index] + data['width'][word_index] / 2 + min_x
    word_y = data['top'][word_index] + data['height'][word_index] / 2 + min_y