# Безопасный снимок формы контейнеров VPS

`vps/preflight-container-shape.sh` дополняет обычный runtime capture структурой, которая нужна для проектирования воспроизводимой установки.

Он читает только:

- repository tags/digests образа, если Docker их знает;
- имена подключённых Docker-сетей;
- тип и **destination** mount без host source path;
- container port/protocol и только число bindings, без host IP/port;
- exposed ports;
- AutoRemove;
- ReadonlyRootfs.

Он не читает и не публикует:

- Env;
- IP-адреса;
- host port numbers;
- host mount source paths;
- labels;
- container command/entrypoint;
- содержимое конфигов;
- ключи, PSK, пароли и токены.

Этот capture нужен для построения параметризуемого VPS installer. Даже после него secrets, локальные пути хранения и внешние порты должны задаваться локально пользователем или генерироваться установщиком, а не храниться в Git.
