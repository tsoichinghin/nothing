import pyautogui
import time
import pytesseract
import subprocess

def close_app():
    while True:
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
                print("PacketShare window already opened")
                pyautogui.leftClick(1208, 373)
                print("Withdrawn closed.")
                time.sleep(5)
                pyautogui.leftClick(1150, 395)
                print("PacketShare upgrade closed.")
                time.sleep(5)
                pyautogui.leftClick(955, 615)
                print("Network exception closed.")
                time.sleep(5)
                pyautogui.leftClick(1406, 260)
                print("PacketShare closed.")
                time.sleep(5)
                pyautogui.leftClick(145, 45)
                print("Wine closed.")
                time.sleep(5)
                pyautogui.leftClick(845, 595)
                print("System problem closed.")
                time.sleep(5)
                pyautogui.leftClick(1264, 475)
                print("Software updater closed.")
                time.sleep(5)
            else:
                print("Not found email. Its means PacketShare in the loading pages")
                command = ['pkill', '-9', '-f', 'PacketShare.exe']
                subprocess.Popen(command)
                print("PacketShare.exe already killed")
                time.sleep(10)
        else:
            pyautogui.leftClick(1208, 373)
            print("Withdrawn closed.")
            time.sleep(5)
            pyautogui.leftClick(1150, 395)
            print("PacketShare upgrade closed.")
            time.sleep(5)
            pyautogui.leftClick(955, 615)
            print("Network exception closed.")
            time.sleep(5)
            pyautogui.leftClick(1406, 260)
            print("PacketShare closed.")
            time.sleep(5)
            pyautogui.leftClick(145, 45)
            print("Wine closed.")
            time.sleep(5)
            pyautogui.leftClick(845, 595)
            print("System problem closed.")
            time.sleep(5)
            pyautogui.leftClick(1264, 475)
            print("Software updater closed.")
            time.sleep(5)

close_app()
