# STACloudMultiEgg

Bộ sưu tập Docker image dành cho hệ thống Egg của Pterodactyl, được xây dựng và duy trì bởi **STACloud**. Mỗi image được rebuild định kỳ để đảm bảo các dependencies luôn được cập nhật mới nhất.

Các image được host trên `ghcr.io` tại namespace `sta-cloud-dev/deverlopment`. Logic phân loại image như sau:

- **Deverlopment** — các image tổng quát cho phép nhiều loại ứng dụng hoặc script chạy được. Thường là một phiên bản cụ thể của một phần mềm (ví dụ: Python), giúp các Egg trong Pterodactyl có thể hoán đổi runtime linh hoạt.

Tất cả image hỗ trợ cả `linux/amd64` và `linux/arm64`. Để sử dụng trên hệ thống arm64, không cần chỉnh sửa gì — dùng tag như bình thường là được.

---

## Đóng góp

Khi thêm một phiên bản mới vào image có sẵn (ví dụ: python 3.15), hãy tạo thư mục con tương ứng, ví dụ `python/3.15/Dockerfile`. Đồng thời cập nhật file workflow trong `.github/workflows/` để đảm bảo phiên bản mới được tag đúng cách.

---

## Danh sách Image

### [Python](python)

| Phiên bản | Image | Trạng thái |
|-----------|-------|------------|
| Python 2.7 | `ghcr.io/sta-cloud-dev/deverlopment:python_2.7` | End-of-Life (EOL) |
| Python 3.7 | `ghcr.io/sta-cloud-dev/deverlopment:python_3.7` | End-of-Life (EOL) |
| Python 3.8 | `ghcr.io/sta-cloud-dev/deverlopment:python_3.8` | End-of-Life (EOL) |
| Python 3.9 | `ghcr.io/sta-cloud-dev/deverlopment:python_3.9` | Chỉ vá bảo mật |
| Python 3.10 | `ghcr.io/sta-cloud-dev/deverlopment:python_3.10` | Chỉ vá bảo mật |
| Python 3.11 | `ghcr.io/sta-cloud-dev/deverlopment:python_3.11` | Đang hỗ trợ |
| Python 3.12 | `ghcr.io/sta-cloud-dev/deverlopment:python_3.12` | Đang hỗ trợ |
| Python 3.13 | `ghcr.io/sta-cloud-dev/deverlopment:python_3.13` | Đang hỗ trợ |
| Python 3.14 | `ghcr.io/sta-cloud-dev/deverlopment:python_3.14` | Pre-release |

### [Bun](bun)

| Phiên bản | Image | Trạng thái |
|-----------|-------|------------|
| Bun Latest | `ghcr.io/sta-cloud-dev/deverlopment:bun_latest` | Đang hỗ trợ |
| Bun Canary | `ghcr.io/sta-cloud-dev/deverlopment:bun_canary` | Canary (không ổn định) |

### Java

| Phiên bản | Image | Trạng thái |
|-----------|-------|------------|
| Java 8 | `ghcr.io/sta-cloud-dev/deverlopment:java_8` | Đang hỗ trợ |
| Java 8 (J9) | `ghcr.io/sta-cloud-dev/deverlopment:java_8j9` | Đang hỗ trợ |
| Java 11 | `ghcr.io/sta-cloud-dev/deverlopment:java_11` | Đang hỗ trợ |
| Java 11 (J9) | `ghcr.io/sta-cloud-dev/deverlopment:java_11j9` | Đang hỗ trợ |
| Java 16 | `ghcr.io/sta-cloud-dev/deverlopment:java_16` | Đang hỗ trợ |
| Java 16 (J9) | `ghcr.io/sta-cloud-dev/deverlopment:java_16j9` | Đang hỗ trợ |
| Java 17 | `ghcr.io/sta-cloud-dev/deverlopment:java_17` | Đang hỗ trợ |
| Java 18 | `ghcr.io/sta-cloud-dev/deverlopment:java_18` | Đang hỗ trợ |
| Java 18 (J9) | `ghcr.io/sta-cloud-dev/deverlopment:java_18j9` | Đang hỗ trợ |
| Java 19 | `ghcr.io/sta-cloud-dev/deverlopment:java_19` | Đang hỗ trợ |
| Java 19 (J9) | `ghcr.io/sta-cloud-dev/deverlopment:java_19j9` | Đang hỗ trợ |
| Java 21 | `ghcr.io/sta-cloud-dev/deverlopment:java_21` | Đang hỗ trợ |
| Java 21 (J9) | `ghcr.io/sta-cloud-dev/deverlopment:java_21j9` | Đang hỗ trợ |
| Java 22 | `ghcr.io/sta-cloud-dev/deverlopment:java_22` | Đang hỗ trợ |
| Java 25 | `ghcr.io/sta-cloud-dev/deverlopment:java_25` | Đang hỗ trợ |

### C# / .NET

| Phiên bản | Image | Trạng thái |
|-----------|-------|------------|
| .NET 8 | `ghcr.io/sta-cloud-dev/deverlopment:dotnet_8` | Đang hỗ trợ |
| .NET 7 | `ghcr.io/sta-cloud-dev/deverlopment:dotnet_7` | Đang hỗ trợ |
| .NET 6 | `ghcr.io/sta-cloud-dev/deverlopment:dotnet_6` | Đang hỗ trợ |
| .NET 5 | `ghcr.io/sta-cloud-dev/deverlopment:dotnet_5` | End-of-Life (EOL) |
| .NET 3.1 | `ghcr.io/sta-cloud-dev/deverlopment:dotnet_3.1` | End-of-Life (EOL) |
| .NET 2.1 | `ghcr.io/sta-cloud-dev/deverlopment:dotnet_2.1` | End-of-Life (EOL) |

### Nodejs

| Phiên bản | Image | Trạng thái |
|-----------|-------|------------|
| Nodejs 25 | `ghcr.io/sta-cloud-dev/deverlopment:nodejs_25` | Current |
| Nodejs 24 | `ghcr.io/sta-cloud-dev/deverlopment:nodejs_24` | Đang hỗ trợ |
| Nodejs 23 | `ghcr.io/sta-cloud-dev/deverlopment:nodejs_23` | Current |
| Nodejs 22 | `ghcr.io/sta-cloud-dev/deverlopment:nodejs_22` | LTS |
| Nodejs 21 | `ghcr.io/sta-cloud-dev/deverlopment:nodejs_21` | End-of-Life (EOL) |
| Nodejs 20 | `ghcr.io/sta-cloud-dev/deverlopment:nodejs_20` | Maintenance LTS |
| Nodejs 19 | `ghcr.io/sta-cloud-dev/deverlopment:nodejs_19` | End-of-Life (EOL) |
| Nodejs 18 | `ghcr.io/sta-cloud-dev/deverlopment:nodejs_18` | End-of-Life (EOL) |
| Nodejs 17 | `ghcr.io/sta-cloud-dev/deverlopment:nodejs_17` | End-of-Life (EOL) |
| Nodejs 16 | `ghcr.io/sta-cloud-dev/deverlopment:nodejs_16` | End-of-Life (EOL) |
| Nodejs 14 | `ghcr.io/sta-cloud-dev/deverlopment:nodejs_14` | End-of-Life (EOL) |
| Nodejs 12 | `ghcr.io/sta-cloud-dev/deverlopment:nodejs_12` | End-of-Life (EOL) |

### Golang

| Phiên bản | Image | Trạng thái |
|-----------|-------|------------|
| Golang 1.24 | `ghcr.io/sta-cloud-dev/deverlopment:golang1.24` | Đang hỗ trợ |

---

## Egg Game

### Minecraft

#### Paper

[Paper](https://papermc.io/)

Pterodactyl Egg dành cho máy chủ Minecraft Paper, dùng image Java của STACloud và script cài đặt tải bản Paper theo phiên bản Minecraft và build number.

#### Cách import Egg

1. Đăng nhập vào **Admin Panel** của Pterodactyl.
2. Vào **Nests** -> chọn hoặc tạo một Nest mới.
3. Nhấn **Import Egg** và upload file `egg-paper.json`.

#### Java Images

| Phiên bản | Image |
|-----------|-------|
| Java 22 | `ghcr.io/sta-cloud-dev/deverlopment:java_22` |
| Java 21 | `ghcr.io/sta-cloud-dev/deverlopment:java_21` |
| Java 17 | `ghcr.io/sta-cloud-dev/deverlopment:java_17` |
| Java 16 | `ghcr.io/sta-cloud-dev/deverlopment:java_16` |
| Java 11 | `ghcr.io/sta-cloud-dev/deverlopment:java_11` |
| Java 8 | `ghcr.io/sta-cloud-dev/deverlopment:java_8` |

#### Biến môi trường

| Biến | Mô tả | Mặc định |
|------|-------|----------|
| `MINECRAFT_VERSION` | Phiên bản Minecraft cần tải. Giá trị không hợp lệ sẽ fallback về bản mới nhất. | `latest` |
| `SERVER_JARFILE` | Tên file jar dùng để khởi động server. | `server.jar` |
| `BUILD_NUMBER` | Số build của Paper cho phiên bản Minecraft đã chọn. Giá trị không hợp lệ sẽ fallback về build mới nhất. | `latest` |
| `DL_PATH` | URL tải jar tùy chỉnh thay cho luồng tải mặc định của Paper. | _(trống)_ |

#### Lệnh khởi động mặc định

```bash
java -Xms128M -Xmx{{SERVER_MEMORY}}M -Dterminal.jline=false -Dterminal.ansi=true -jar {{SERVER_JARFILE}}
```

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

### [Bun](bun)

[bun](https://bun.sh/)

Pterodactyl Egg tổng quát cho Bun — hỗ trợ chạy ứng dụng JavaScript/TypeScript từ Git repo hoặc file tự upload. Tự động chạy `bun install` nếu có `package.json`.

#### Cách import Egg

1. Đăng nhập vào **Admin Panel** của Pterodactyl.
2. Vào **Nests** → chọn hoặc tạo một Nest mới.
3. Nhấn **Import Egg** và upload file `BunGeneric.json`.

#### Biến môi trường

| Biến | Mô tả | Mặc định |
|------|-------|----------|
| `MAIN_FILE` | File hoặc script khởi động ứng dụng | `index.js` |
| `GIT_ADDRESS` | URL Git repo cần clone | _(trống)_ |
| `BRANCH` | Branch cần clone (để trống = branch mặc định) | _(trống)_ |
| `USERNAME` | Tên đăng nhập Git (repo private) | _(trống)_ |
| `ACCESS_TOKEN` | Personal Access Token Git (repo private) | _(trống)_ |
| `USER_UPLOAD` | Bỏ qua cài đặt nếu tự upload file (`0`/`1`) | `0` |
| `AUTO_UPDATE` | Tự động `git pull` khi khởi động (`0`/`1`) | `0` |

#### Lệnh khởi động mặc định

```bash
if [[ -d .git ]] && [[ "{{AUTO_UPDATE}}" == "1" ]]; then git pull; fi
if [ -f package.json ]; then bun install; fi
bun run "{{MAIN_FILE}}"
```

---

### Java

Pterodactyl Egg tổng quát cho Java — hỗ trợ chạy ứng dụng Java từ file JAR với nhiều phiên bản runtime khác nhau (8, 11, 16, 18, 19, 21, 22, 25).

#### Cách import Egg

1. Đăng nhập vào **Admin Panel** của Pterodactyl.
2. Vào **Nests** → chọn hoặc tạo một Nest mới.
3. Nhấn **Import Egg** và upload file `JavaGeneric.json`.

#### Biến môi trường

| Biến | Mô tả | Mặc định |
|------|-------|----------|
| `JARFILE` | Tên file JAR cần chạy | `server.jar` |

#### Lệnh khởi động mặc định

```bash
java -Dterminal.jline=false -Dterminal.ansi=true -jar {{JARFILE}}
```

---

### C# / .NET

[dotnet](https://dotnet.microsoft.com/)

Pterodactyl Egg tổng quát cho C#/.NET — hỗ trợ chạy dự án từ Git repo hoặc file tự upload, có thể chuyển đổi nhiều phiên bản .NET khác nhau qua image.

#### Cách import Egg

1. Đăng nhập vào **Admin Panel** của Pterodactyl.
2. Vào **Nests** → chọn hoặc tạo một Nest mới.
3. Nhấn **Import Egg** và upload file `CGeneric.json`.

#### Biến môi trường

| Biến | Mô tả | Mặc định |
|------|-------|----------|
| `PROJECT_FILE` | File `.csproj` chính cần chạy | _(trống)_ |
| `PROJECT_DIR` | Thư mục chứa file `.csproj` | `/home/container` |
| `GIT_ADDRESS` | URL Git repo cần clone | _(trống)_ |
| `BRANCH` | Branch cần clone | _(trống)_ |
| `USERNAME` | Tên đăng nhập Git | _(trống)_ |
| `ACCESS_TOKEN` | Personal Access Token Git | _(trống)_ |
| `USER_UPLOAD` | Bỏ qua bước clone repo (`0`/`1`) | `0` |
| `AUTO_UPDATE` | Tự động `git pull` khi khởi động (`0`/`1`) | `0` |

#### Lệnh khởi động mặc định

```bash
if [ -d .git ] && [ "{{AUTO_UPDATE}}" = "1" ]; then git pull; fi; cd {{PROJECT_DIR}}; dotnet restore; dotnet run --project {{PROJECT_FILE}}
```

---

### Nodejs

[nodejs](https://nodejs.org/)

Pterodactyl Egg tổng quát cho Nodejs — hỗ trợ chạy ứng dụng từ Git repo hoặc file tự upload, tự động `npm install` nếu có `package.json`.

#### Cách import Egg

1. Đăng nhập vào **Admin Panel** của Pterodactyl.
2. Vào **Nests** → chọn hoặc tạo một Nest mới.
3. Nhấn **Import Egg** và upload file `NodejsGeneric.json`.

#### Biến môi trường

| Biến | Mô tả | Mặc định |
|------|-------|----------|
| `JS_FILE` | File Nodejs chính cần chạy | `index.js` |
| `GIT_ADDRESS` | URL Git repo cần clone | _(trống)_ |
| `BRANCH` | Branch cần clone | _(trống)_ |
| `USERNAME` | Tên đăng nhập Git | _(trống)_ |
| `ACCESS_TOKEN` | Personal Access Token Git | _(trống)_ |
| `USER_UPLOAD` | Bỏ qua bước clone repo (`0`/`1`) | `0` |
| `AUTO_UPDATE` | Tự động `git pull` khi khởi động (`0`/`1`) | `0` |

#### Lệnh khởi động mặc định

```bash
if [ -d .git ] && [ "{{AUTO_UPDATE}}" = "1" ]; then git pull; fi; if [ -f package.json ]; then npm install; fi; node "{{JS_FILE}}"
```

---

### Golang

[golang](https://go.dev/)

Pterodactyl Egg tổng quát cho Golang, dùng để tải package Go, build thành file thực thi, rồi chạy trực tiếp bằng executable đã build.

#### Cách import Egg

1. Đăng nhập vào **Admin Panel** của Pterodactyl.
2. Vào **Nests** → chọn hoặc tạo một Nest mới.
3. Nhấn **Import Egg** và upload file `GolangGeneric.json`.

#### Biến môi trường

| Biến | Mô tả | Mặc định |
|------|-------|----------|
| `GO_PACKAGE` | Go package cần tải và build | _(trống)_ |
| `EXECUTABLE` | Tên file thực thi sau khi build | _(trống)_ |

#### Lệnh khởi động mặc định

```bash
./${EXECUTABLE}
```

---

## Giấy phép

Dự án này được cấp phép theo [MIT License](LICENSE).  
### OpenClaw

[OpenClaw](https://openclaw.ai/)

Pterodactyl Egg cho OpenClaw Gateway, state trong /home/container/.openclaw.

#### CÃ¡ch import Egg

1. ÄÄƒng nháº­p vÃ o **Admin Panel** cá»§a Pterodactyl.
2. VÃ o **Nests** â†’ chá»n hoáº·c táº¡o má»™t Nest má»›i.
3. Nháº¥n **Import Egg** vÃ  upload file `OpenClaw.json`.

#### Image

| PhiÃªn báº£n | Image | Tráº¡ng thÃ¡i |
|-----------|-------|------------|
| OpenClaw Latest | `ghcr.io/sta-cloud-dev/ai:openclaw_latest` | Äang há»— trá»£ |

#### Biáº¿n mÃ´i trÆ°á»ng

| Biáº¿n | MÃ´ táº£ | Máº·c Ä‘á»‹nh |
|------|-------|----------|
| `OPENCLAW_BIND` | Cháº¿ Ä‘á»™ bind gateway (`loopback`, `lan`, `tailnet`, `auto`, `custom`) | `lan` |
| `OPENCLAW_GATEWAY_TOKEN` | Token káº¿t ná»‘i gateway | _(trá»‘ng)_ |
| `OPENCLAW_VERBOSE` | Báº­t log chi tiáº¿t (`true`/`false`) | `true` |
| `OPENCLAW_ARGS` | Tham sá»‘ bá»• sung cho `openclaw gateway` | _(trá»‘ng)_ |

#### Lá»‡nh khá»Ÿi Ä‘á»™ng máº·c Ä‘á»‹nh

```bash
mkdir -p /home/container/.openclaw /home/container/.openclaw/workspace /home/container/.openclaw/skills
export OPENCLAW_HOME=/home/container/.openclaw
export HOME=/home/container
EXTRA_ARGS="${OPENCLAW_ARGS}"
if [ "${OPENCLAW_VERBOSE}" = "true" ]; then EXTRA_ARGS="${EXTRA_ARGS} --verbose"; fi
if [ -n "${OPENCLAW_GATEWAY_TOKEN}" ]; then EXTRA_ARGS="${EXTRA_ARGS} --token ${OPENCLAW_GATEWAY_TOKEN}"; fi
openclaw gateway --allow-unconfigured --bind ${OPENCLAW_BIND} --port {{server.build.default.port}} ${EXTRA_ARGS}
```
