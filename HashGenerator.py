import os
import hashlib
import json

def calculate_file_hash(file_path):
    """Calculate the hash of a single file."""
    sha256 = hashlib.sha256()
    with open(file_path, 'rb') as f:
        while chunk := f.read(8192):
            sha256.update(chunk)
    return sha256.hexdigest()

def calculate_directory_hashes(directory):
    """Calculates the hashes of all files in a directory and subdirectories."""
    file_hashes = {}
    for root, _, files in os.walk(directory):
        for file in files:
            file_path = os.path.join(root, file)
            file_hash = calculate_file_hash(file_path)
            relative_path = os.path.relpath(file_path, directory)
            file_hashes[relative_path] = file_hash
    return file_hashes

def load_saved_hashes(hash_file_path):
    """Loads saved hashes from a JSON file."""
    if os.path.exists(hash_file_path):
        with open(hash_file_path, 'r') as hash_file:
            return json.load(hash_file)
    return {}

def save_hashes(hash_file_path, file_hashes):
    """Saves the hashes to a JSON file."""
    with open(hash_file_path, 'w') as hash_file:
        json.dump(file_hashes, hash_file, indent=4)

def compare_hashes(current_hashes, saved_hashes):
    """Compares current hashes with saved ones and identifies changes."""
    modified_files = []
    new_files = []
    removed_files = []

    for file, current_hash in current_hashes.items():
        if file not in saved_hashes:
            new_files.append(file)
        elif current_hash != saved_hashes[file]:
            modified_files.append(file)

    for file in saved_hashes:
        if file not in current_hashes:
            removed_files.append(file)

    return modified_files, new_files, removed_files

def main():
    directory = "your/directory"
    hash_file_path = os.path.join(directory, "file_hashes.json")

    # Calcula os hashes atuais dos arquivos no diretório
    current_hashes = calculate_directory_hashes(directory)

    # Carrega os hashes salvos anteriormente
    saved_hashes = load_saved_hashes(hash_file_path)

    # Compara os hashes atuais com os salvos
    modified_files, new_files, removed_files = compare_hashes(current_hashes, saved_hashes)

    # Exibe os resultados
    if modified_files:
        print("Modified files:")
        for file in modified_files:
            print(f"  {file}")

    if new_files:
        print("New files:")
        for file in new_files:
            print(f"  {file}")

    if removed_files:
        print("Removed files:")
        for file in removed_files:
            print(f"  {file}")

    # Salva os hashes atuais para futuras comparações
    save_hashes(hash_file_path, current_hashes)

if __name__ == "__main__":
    main()
