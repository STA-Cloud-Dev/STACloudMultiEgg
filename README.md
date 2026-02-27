# STACloudMultiEgg

> Docker images và Pterodactyl Egg hỗ trợ nhiều phiên bản Python, được xây dựng bởi **STACloud**.

---

## Giới thiệu

**STACloudMultiEgg** cung cấp các Docker image Alpine nhẹ và một Pterodactyl Egg (`PythonGeneric.json`) để chạy ứng dụng Python trên [Pterodactyl Panel](https://pterodactyl.io/).  
Hỗ trợ đầy đủ từ Python **2.7** đến Python **3.14**, bao gồm các bản đang được bảo trì và bản pre-release.

---

## Docker Images

Tất cả image được publish tại `ghcr.io/sunshroomchan/publicdork` và dựa trên Alpine Linux.

| Tag | Phiên bản | Trạng thái |
|-----|-----------|------------|
| `python_2.7` | Python 2.7 | End-of-Life (EOL) |
| `python_3.7` | Python 3.7 | End-of-Life (EOL) |
| `python_3.8` | Python 3.8 | End-of-Life (EOL) |
| `python_3.9` | Python 3.9 | Security fixes only |
| `python_3.10` | Python 3.10 | Security fixes only |
| `python_3.11` | Python 3.11 | Active |
| `python_3.12` | Python 3.12 | Active |
| `python_3.13` | Python 3.13 | Active |
| `python_3.14` | Python 3.14 | Pre-release |

### Phần mềm được cài sẵn trong mỗi image

- `cmake`, `make`, `gcc`, `g++`
- `git`, `curl`, `openssl`, `sqlite`
- `ffmpeg`, `ca-certificates`, `tzdata`, `tar`
- User không có quyền root: `container` (`/home/container`)

---

## Pterodactyl Egg

File `PythonGeneric.json` là egg sẵn sàng import vào Pterodactyl Panel.

### Cách import egg

1. Đăng nhập vào **Admin Panel** của Pterodactyl.
2. Vào **Nests** → chọn hoặc tạo một Nest mới.
3. Nhấn **Import Egg** và upload file `PythonGeneric.json`.

### Biến môi trường

| Biến | Mô tả | Mặc định |
|------|-------|----------|
| `PY_FILE` | File Python khởi động ứng dụng | `app.py` |
| `PY_PACKAGES` | Các package Python bổ sung (cách nhau bằng dấu cách) | _(trống)_ |
| `REQUIREMENTS_FILE` | Tên file requirements | `requirements.txt` |
| `GIT_ADDRESS` | URL Git repo cần clone | _(trống)_ |
| `BRANCH` | Branch cần clone (để trống = branch mặc định) | _(trống)_ |
| `USERNAME` | Tên đăng nhập Git (cho repo private) | _(trống)_ |
| `ACCESS_TOKEN` | Personal Access Token Git (cho repo private) | _(trống)_ |
| `USER_UPLOAD` | Bỏ qua bước cài đặt nếu tự upload file (`0`/`1`) | `0` |
| `AUTO_UPDATE` | Tự động `git pull` khi khởi động (`0`/`1`) | `0` |

### Lệnh khởi động mặc định

```bash
if [[ -d .git ]] && [[ "{{AUTO_UPDATE}}" == "1" ]]; then git pull; fi
if [[ ! -z "{{PY_PACKAGES}}" ]]; then pip install -U --prefix .local {{PY_PACKAGES}}; fi
if [[ -f /home/container/${REQUIREMENTS_FILE} ]]; then pip install -U --prefix .local -r ${REQUIREMENTS_FILE}; fi
/usr/local/bin/python /home/container/{{PY_FILE}}
```

---

## Cấu trúc thư mục

```
STACloudMultiEgg/
├── PythonGeneric.json       # Pterodactyl Egg
└── python/
    ├── entrypoint.sh        # Script khởi động container
    ├── 2.7/Dockerfile
    ├── 3.7/Dockerfile
    ├── 3.8/Dockerfile
    ├── 3.9/Dockerfile
    ├── 3.10/Dockerfile
    ├── 3.11/Dockerfile
    ├── 3.12/Dockerfile
    ├── 3.13/Dockerfile
    └── 3.14/Dockerfile
```

---

## Build image thủ công

```bash
# Ví dụ build image Python 3.12
cd python/3.12
docker build -t my-python:3.12 .
```

---

## Giấy phép

Dự án này được cấp phép theo [MIT License](LICENSE).  
Docker image dựa trên công việc gốc của [Matthew Penner](https://github.com/matthewpi) từ [pterodactyl/yolks](https://github.com/pterodactyl/yolks).

---

## Liên hệ

- **Tác giả**: STACloud — admin@stacloud.vn
- **GitHub**: [sunshroomchan/publicdork](https://github.com/sunshroomchan/publicdork)
