import pyautogui
import pytesseract
import subprocess

screenshot = image = data = target_word = word_index = word_x = word_y = None
min_x, max_x = 0, 1919
min_y, max_y = 0, 1079
width = max_x - min_x
height = max_y - min_y
screenshot = pyautogui.screenshot(region=(min_x, min_y, width, height))
image = screenshot.convert('L')
data = pytesseract.image_to_data(image, output_type=pytesseract.Output.DICT)
print("Text on screenshot:", data)
target_word = "Packetshare"
if target_word in data['text']:
    print("Found PacketShare window")
    target_word = None
    target_word = "tsoichinghin@gmail.com"
    if target_word in data['text']:
        print("PacketShare window found, good.")
    else:
        print("Not found email. Its means PacketShare in the loading pages")
        command = ['pkill', '-9', '-f', 'PacketShare.exe']
        subprocess.Popen(command)
        print("PacketShare.exe already killed")
