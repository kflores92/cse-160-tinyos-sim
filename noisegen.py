import random

with open("noise/noise.txt", "w") as f:
    for i in range(155):
        num = random.randint(-95, -45);
        x = str(num)
        f.write(x + "\n");