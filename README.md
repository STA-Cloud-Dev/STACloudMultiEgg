# STACloudMultiEgg

Bộ sưu tập Docker image dành cho hệ thống Egg của Pterodactyl, được xây dựng và duy trì bởi **STACloud**. Mỗi image được rebuild định kỳ để đảm bảo các dependencies luôn được cập nhật mới nhất.

Các image được host trên `ghcr.io` tại namespace `trolyamazon/yolks`. Logic phân loại image như sau:

- **yolks** — các image tổng quát cho phép nhiều loại ứng dụng hoặc script chạy được. Thường là một phiên bản cụ thể của một phần mềm (ví dụ: Python), giúp các Egg trong Pterodactyl có thể hoán đổi runtime linh hoạt.

Tất cả image hỗ trợ cả `linux/amd64` và `linux/arm64`. Để sử dụng trên hệ thống arm64, không cần chỉnh sửa gì — dùng tag như bình thường là được.

---

## Đóng góp

Khi thêm một phiên bản mới vào image có sẵn (ví dụ: python 3.15), hãy tạo thư mục con tương ứng, ví dụ `python/3.15/Dockerfile`. Đồng thời cập nhật file workflow trong `.github/workflows/` để đảm bảo phiên bản mới được tag đúng cách.

---

## Danh sách Image

### [Python](python)

| Phiên bản | Image | Trạng thái |
|-----------|-------|------------|
| Python 2.7 | `ghcr.io/trolyamazon/yolks:python_2.7` | End-of-Life (EOL) |
| Python 3.7 | `ghcr.io/trolyamazon/yolks:python_3.7` | End-of-Life (EOL) |
| Python 3.8 | `ghcr.io/trolyamazon/yolks:python_3.8` | End-of-Life (EOL) |
| Python 3.9 | `ghcr.io/trolyamazon/yolks:python_3.9` | Chỉ vá bảo mật |
| Python 3.10 | `ghcr.io/trolyamazon/yolks:python_3.10` | Chỉ vá bảo mật |
| Python 3.11 | `ghcr.io/trolyamazon/yolks:python_3.11` | Đang hỗ trợ |
| Python 3.12 | `ghcr.io/trolyamazon/yolks:python_3.12` | Đang hỗ trợ |
| Python 3.13 | `ghcr.io/trolyamazon/yolks:python_3.13` | Đang hỗ trợ |
| Python 3.14 | `ghcr.io/trolyamazon/yolks:python_3.14` | Pre-release |

---

## Egg Generic

### [Python](python)

[python](https://www.python.org/)

Pterodactyl Egg tổng quát cho Python — hỗ trợ chạy ứng dụng Python từ Git repo hoặc file tự upload. Tương thích với mọi phiên bản image liệt kê ở trên.

#### Cách import Egg

1. Đăng nhập vào **Admin Panel** của Pterodactyl.
2. Vào **Nests** → chọn hoặc tạo một Nest mới.
3. Nhấn **Import Egg** và upload file `PythonGeneric.json`.

#### Biến môi trường

| Biến | Mô tả | Mặc định |
|------|-------|----------|
| `PY_FILE` | File Python khởi động ứng dụng | `main.py` |
| `PY_PACKAGES` | Package Python bổ sung (cách nhau bằng dấu cách) | _(trống)_ |
| `REQUIREMENTS_FILE` | Tên file requirements | `requirements.txt` |
| `GIT_ADDRESS` | URL Git repo cần clone | _(trống)_ |
| `BRANCH` | Branch cần clone (để trống = branch mặc định) | _(trống)_ |
| `USERNAME` | Tên đăng nhập Git (repo private) | _(trống)_ |
| `ACCESS_TOKEN` | Personal Access Token Git (repo private) | _(trống)_ |
| `USER_UPLOAD` | Bỏ qua cài đặt nếu tự upload file (`0`/`1`) | `0` |
| `AUTO_UPDATE` | Tự động `git pull` khi khởi động (`0`/`1`) | `0` |

#### Lệnh khởi động mặc định

```bash
if [[ -d .git ]] && [[ "{{AUTO_UPDATE}}" == "1" ]]; then git pull; fi
if [[ ! -z "{{PY_PACKAGES}}" ]]; then pip install -U --prefix .local {{PY_PACKAGES}}; fi
if [[ -f /home/container/${REQUIREMENTS_FILE} ]]; then pip install -U --prefix .local -r ${REQUIREMENTS_FILE}; fi
/usr/local/bin/python /home/container/{{PY_FILE}}
```

---

## Giấy phép

Dự án này được cấp phép theo [MIT License](LICENSE).  
