import time
import pyautogui

def close_app():
    while True:
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
