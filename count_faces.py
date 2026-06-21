import os

obj_path = r"C:\Users\cia\Downloads\nami-onepiece\export_obj_split\nami.obj"
current_mtl = "None"
counts = {}

with open(obj_path, "r") as f:
    for line in f:
        if line.startswith("usemtl "):
            current_mtl = line.split()[1].strip()
            if current_mtl not in counts:
                counts[current_mtl] = 0
        elif line.startswith("f "):
            if current_mtl in counts:
                counts[current_mtl] += 1

print("Face counts per material:")
for k, v in counts.items():
    print(f"{k}: {v} faces")
