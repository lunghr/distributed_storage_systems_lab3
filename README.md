# Distributed Storage Systems | Lab 3 | P3309 | Tupichenko Mila

## Задание

Цель работы - настроить процедуру периодического резервного копирования базы данных, сконфигурированной в ходе
выполнения [лабораторной работы №2](https://github.com/lunghr/distributed_storage_systems_lab2), а также разработать и
отладить сценарии восстановления в случае сбоев.

Узел из предыдущей лабораторной работы используется в качестве основного. Новый узел используется в качестве резервного.
Учётные данные для подключения к новому узлу выдаёт преподаватель. В сценариях восстановления необходимо использовать
копию данных, полученную на первом этапе данной лабораторной работы.

---

### Этап 1. Резервное копирование

Настроить резервное копирование с основного узла на резервный следующим образом:

- Периодические полные копии с помощью SQL Dump.
- По расписанию (cron) раз в сутки, методом SQL Dump с сжатием. Созданные архивы должны сразу перемещаться на резервный
  хост, они не должны храниться на основной системе. Срок хранения архивов на резервной системе - 4 недели. По истечении
  срока хранения, старые архивы должны автоматически уничтожаться.
- Подсчитать, каков будет объем резервных копий спустя месяц работы системы, исходя из следующих условий:
- Средний объем новых данных в БД за сутки: 300МБ.
- Средний объем измененных данных за сутки: 650МБ.
- Проанализировать результаты.

---

### Этап 2. Потеря основного узла

Этот сценарий подразумевает полную недоступность основного узла. Необходимо восстановить работу СУБД на РЕЗЕРВНОМ узле,
продемонстрировать успешный запуск СУБД и доступность данных.

---

### Этап 3. Повреждение файлов БД

Этот сценарий подразумевает потерю данных (например, в результате сбоя диска или файловой системы) при сохранении
доступности основного узла. Необходимо выполнить полное восстановление данных из резервной копии и перезапустить СУБД на
ОСНОВНОМ узле.

Ход работы:

- Симулировать сбой:
    - удалить с диска директорию WAL со всем содержимым.
- Проверить работу СУБД, доступность данных, перезапустить СУБД, проанализировать результаты.
- Выполнить восстановление данных из резервной копии, учитывая следующее условие:
    - исходное расположение дополнительных табличных пространств недоступно - разместить в другой директории и
      скорректировать конфигурацию.
- Запустить СУБД, проверить работу и доступность данных, проанализировать результаты.

---

### Этап 4. Логическое повреждение данных

Этот сценарий подразумевает частичную потерю данных (в результате нежелательной или ошибочной операции) при сохранении
доступности основного узла. Необходимо выполнить восстановление данных на ОСНОВНОМ узле следующим способом:

- Восстановление с использованием архивных WAL файлов. (СУБД должна работать в режиме архивирования WAL, потребуется
  задать параметры восстановления).

Ход работы:

- В каждую таблицу базы добавить 2-3 новые строки, зафиксировать результат.
- Зафиксировать время и симулировать ошибку:
    - удалить любые две таблицы (DROP TABLE)
- Продемонстрировать результат.
- Выполнить восстановление данных указанным способом.
- Продемонстрировать и проанализировать результат.

---

## Выполнение

### Этап 1. Резервное копирование

**Предварительно были прокинуты ssh ключи**

**Основной**

```bash
#!/usr/local/bin/bash

pg_dumpall -U postgres0 -p 9136 | gzip
```

**Резервный**

```bash
#!/usr/local/bin/bash

DATE=$(date +"%Y-%m-%d")
BACKUP_NAME="cluster_$DATE.sql.gz"
BACKUP_DIR=~
REMOTE_USER=postgres0
REMOTE_HOST=pg155.cs.ifmo.ru

ssh "$REMOTE_USER@$REMOTE_HOST" "bash dump_cluster.sh" > "$BACKUP_DIR/$BACKUP_NAME"
find "$BACKUP_DIR" -name "cluster_*.sql.gz" -type f -mtime +28 -exec rm -f {} \;
```

Теперь настроим ```cron``` на бэкап раз в сутки в 00:00 (на резервном узле)

```shell
crontab -e

0 0 * * * ~/get_dump.sh >> /var/db/postgres2/backup.log 2>&1

[postgres2@pg158 ~]$ crontab -l
0 0 * * * ~/get_dump.sh >> /var/db/postgres2/backup.log 2>&1
[postgres2@pg158 ~]$
```

---

### Расчёты

Объём в день = +300 МБ, так как в логическом дампе измененные данные не добавляют “вес”, потому что хранится только
актуальная версия таблицы, а старые строки не хранятся (как в wal или базовых бэкапах)

$$
\sum_{d=1}^{30} 300d = 300 \cdot \frac{30 \cdot 31}{2} = 300 \cdot 465 = 139500МБ = 135ГБ
$$

А с учетом сжатия

$$
136Гб \cdot 0.5 = 68ГБ
$$

То есть примерно $$70Гб + 10Гб = 80ГБ$$ (запас на рост) - нужно зарезервировать ```80Гб``` на резервном хосте

---

### Этап 2. Потеря основного узла


```bash
#!/usr/local/bin/bash

DUMP_FILE=~/cluster_$DATE.sql
PGPORT=5432
PGDATA=tah70
OLD_TABLESPACE_DIR='/var/db/postgres0/vwp40'
NEW_TABLESPACE_DIR='/var/db/postgres2/new_vwp40'
DUMP_FILE="cluster_2025-05-25.sql"

gzip -d "$DUMP_FILE".gz

pg_ctl stop -D "$PGDATA"
rm -rf "$PGDATA"/*
rm -rf "$NEW_TABLESPACE_DIR"


export PGDATA=$PGDATA

mkdir -p "$PGDATA"
chmod 700 "$PGDATA"

initdb -D "$PGDATA" --encoding=UTF8 --locale=C
pg_ctl -D "$PGDATA" -o "-p $PGPORT" -w start

mkdir -p "$NEW_TABLESPACE_DIR"
chmod 700 "$NEW_TABLESPACE_DIR"


OLD="LOCATION '$OLD_TABLESPACE_DIR'"
NEW="LOCATION '$NEW_TABLESPACE_DIR'"

sed -i '' "s|$OLD|$NEW|g" cluster_2025-05-25.sql

psql -U postgres2 -p "$PGPORT" -d postgres -f "$DUMP_FILE"
```

<details>
<summary>Результат</summary>
<img src="images/rec_1.png" alt="Скриншот" />

<img src="images/rec_4.png" alt="Скриншот" />
</details>

---

### Этап 3. Повреждение файлов БД

Ломаем файлы

```shell
rm -rf "$PGDATA/pg_wal"/*
pg_ctl -D "$PGDATA" restart 
```

Без перезапуска сервера, зайдя в бд, мы увидим, что все в порядке и наши данные на месте, но при перезапуске сервер не
поднимется. Это связано с тем, что в каталоге pg_wal содержит журналы предзаписи, необходимые для обеспечения
целостности данных при старте. Поэтому сервер не сможет восстановить согласованность бд при перезапуске и откажется
запускаться.

```shell
[postgres0@pg155 ~]$ rm -rf tah70/pg_wal/
[postgres0@pg155 ~]$ ls
backup.log                      globals.sql.gz                  restore_base.sh                 tah70
fargoldcity_2025-05-22.sql      new_vwp40                       scripts                         vwp40
[postgres0@pg155 ~]$ psql -U postgres0 -p 9136 fargoldcity
psql (16.4)
Type "help" for help.

fargoldcity=# \su
invalid command \su
Try \? for help.
fargoldcity=# \du
                             List of roles
 Role name |                         Attributes
-----------+------------------------------------------------------------
 cityuser  |
 postgres0 | Superuser, Create role, Create DB, Replication, Bypass RLS

fargoldcity=# ls
fargoldcity-# select * from test_table;
ERROR:  syntax error at or near "ls"
LINE 1: ls
        ^
fargoldcity=#
select * from test_table;
 id |  name
----+---------
  1 | Alice
  2 | Bob
  3 | Charlie
  4 | David
  5 | Eve
  6 | Frank
  7 | Grace
(7 rows)

fargoldcity=# \q
[postgres0@pg155 ~]$ pg_ctl restart
waiting for server to shut down...... done
server stopped
waiting for server to start....2025-05-22 01:14:00.755 MSK [30833] LOG:  ending log output to stderr
2025-05-22 01:14:00.755 MSK [30833] HINT:  Future log output will go to log destination "syslog".
 stopped waiting
pg_ctl: could not start server
Examine the log output.
[postgres0@pg155 ~]$ psql -U postgres0 -p 9136 fargoldcity
psql: error: connection to server on socket "/tmp/.s.PGSQL.9136" failed: No such file or directory
        Is the server running locally and accepting connections on that socket?
[postgres0@pg155 ~]$
```

Поэтому получаем с резерва последний бэкап и запускаем аналогичный резервному скрипт восстановления базы на основном узле
```bash
#!/usr/local/bin/bash

DUMP_FILE=~/cluster_$DATE.sql
PGPORT=5432
PGDATA=tah70
OLD_TABLESPACE_DIR='/var/db/postgres0/vwp40'
NEW_TABLESPACE_DIR='/var/db/postgres0/new_vwp40'
DUMP_FILE="cluster_2025-05-25.sql"

gzip -d "$DUMP_FILE".gz

pg_ctl stop -D "$PGDATA"
rm -rf "$PGDATA"/*
rm -rf "$NEW_TABLESPACE_DIR"


export PGDATA=$PGDATA

mkdir -p "$PGDATA"
chmod 700 "$PGDATA"

initdb -D "$PGDATA" --encoding=UTF8 --locale=C
pg_ctl -D "$PGDATA" -o "-p $PGPORT" -w start

mkdir -p "$NEW_TABLESPACE_DIR"
chmod 700 "$NEW_TABLESPACE_DIR"


OLD="LOCATION '$OLD_TABLESPACE_DIR'"
NEW="LOCATION '$NEW_TABLESPACE_DIR'"

sed -i '' "s|$OLD|$NEW|g" cluster_2025-05-25.sql

psql -U postgres2 -p "$PGPORT" -d postgres -f "$DUMP_FILE"

```

**Результат**

```shell
[postgres0@pg155 ~]$ ./restore_cluster.sh
gzip: can't stat: cluster_2025-05-25.sql.gz: No such file or directory
ожидание завершения работы сервера.... готово
сервер остановлен
Файлы, относящиеся к этой СУБД, будут принадлежать пользователю "postgres0".
От его имени также будет запускаться процесс сервера.

Кластер баз данных будет инициализирован с локалью "C".
Выбрана конфигурация текстового поиска по умолчанию "english".

Контроль целостности страниц данных отключён.

исправление прав для существующего каталога tah70... ок
создание подкаталогов... ок
выбирается реализация динамической разделяемой памяти... posix
выбирается значение max_connections по умолчанию... 100
выбирается значение shared_buffers по умолчанию... 128MB
выбирается часовой пояс по умолчанию... Europe/Moscow
создание конфигурационных файлов... ок
выполняется подготовительный скрипт... ок
выполняется заключительная инициализация... ок
сохранение данных на диске... ок

initdb: предупреждение: включение метода аутентификации "trust" для локальных подключений
initdb: подсказка: Другой метод можно выбрать, отредактировав pg_hba.conf или ещё раз запустив initdb с ключом -A, --auth-local или --auth-host.

Готово. Теперь вы можете запустить сервер баз данных:

    pg_ctl -D tah70 -l файл_журнала start

ожидание запуска сервера....2025-05-25 21:35:13.581 MSK [66706] LOG:  ending log output to stderr
2025-05-25 21:35:13.581 MSK [66706] HINT:  Future log output will go to log destination "syslog".
 готово
сервер запущен
SET
SET
SET
CREATE ROLE
ALTER ROLE
CREATE ROLE
ALTER ROLE
CREATE TABLESPACE
Вы подключены к базе данных "template1" как пользователь "postgres0".
SET
SET
SET
SET
SET
 set_config
------------

(1 строка)

SET
SET
SET
SET
SET
SET
SET
SET
SET
 set_config
------------

(1 строка)

SET
SET
SET
SET
CREATE DATABASE
ALTER DATABASE
Вы подключены к базе данных "fargoldcity" как пользователь "postgres0".
SET
SET
SET
SET
SET
 set_config
------------

(1 строка)

SET
SET
SET
SET
ALTER SCHEMA
SET
SET
CREATE TABLE
ALTER TABLE
CREATE SEQUENCE
ALTER SEQUENCE
ALTER SEQUENCE
ALTER TABLE
COPY 10
 setval
--------
     40
(1 строка)

ALTER TABLE
SET
CREATE INDEX
GRANT
Вы подключены к базе данных "postgres" как пользователь "postgres0".
SET
SET
SET
SET
SET
 set_config
------------

(1 строка)

SET
SET
SET
SET
[postgres0@pg155 ~]$
```

<details>
<summary>Результаты/summary>
<img src="images/rec_2.png" alt="Скриншот" />
</details>

---

### Этап 4. Логическое повреждение данных

Чтобы восстановить базу после логической ошибки (например, случайного удаления таблиц), нужно заранее включить
сохранение архивных WAL-файлов — это специальные журналы, которые фиксируют все изменения в базе. Плюсом ко всему нам
нужен base backup, так что создаем директорию и для него

Конфигурируем ```postgresql.conf```

```shell
wal_level = replica
archive_mode = on
archive_command = 'cp %p /var/db/postgres0/backups/wal/%f'
```

```wal_level = replica ``` включает расширенное логирование изменений, необходимое для возможности восстановления

```archive_mode = on ```включает режим архивирования WAL-файлов

```archive_command ``` указывает директорию, куда будут сохраняться архивы

Потом создаем директорию для архивов и бэкапов, перезапускаем сервер и заходим в бд

```shell
mkdir -p /var/db/postgres0/backups/wal
mkdir -p /var/db/postgres0/backups/base
chmod 700 /var/db/postgres0/backups/wal
chmod 700 /var/db/postgres0/backups/base
```

```shell
pg_ctl -D $PGDATA restart
psql -U postgres0 -p 9136 fargoldcity
```

Руками создаем бэкап нашей исходной базы

```shell
pg_basebackup -D ~/backups/base/2025-05-22 -Ft -z -P -X stream
```

После чего со спокойной душой можем ломать таблицу

```shell
[postgres0@pg155 ~]$ clear
[postgres0@pg155 ~]$ psql -U postgres0 -p 9136 fargoldcity
psql (16.4)
Type "help" for help.

fargoldcity=# select * from test_table;
 id |  name
----+---------
  1 | Alice
  2 | Bob
  3 | Charlie
  4 | David
  5 | Eve
  6 | Frank
  7 | Grace
(7 rows)

fargoldcity=# INSERT INTO test_table (name) VALUES ('one'), ('two'), ('three');
INSERT 0 3
fargoldcity=# select * from test_table;
 id |  name
----+---------
  1 | Alice
  2 | Bob
  3 | Charlie
  4 | David
  5 | Eve
  6 | Frank
  7 | Grace
  8 | one
  9 | two
 10 | three
(10 rows)

fargoldcity=# SELECT now();
              now
-------------------------------
 2025-05-23 00:05:54.390419+03
(1 row)

fargoldcity=# DROP TABLE test_table;
DROP TABLE
fargoldcity=# select * from test_table;
ERROR:  relation "test_table" does not exist
LINE 1: select * from test_table;
                      ^
fargoldcity=#
```

Теперь нам нужно восстановить базу до состояния до удаления таблицы. Для этого мы будем использовать скрипт ниже

```bash
#!/usr/local/bin/bash

export PGDATA="/var/db/postgres0/tah70"
ARCHIVE_DIR="/var/db/postgres0/wal"
PGUSER="postgres0"
BACKUP_DIR="/var/db/postgres0/backups/base"
BACKUP_FILE="2025-05-22"
WAL="/var/db/postgres0/backups/wal"
PGPORT=9136
TABLESPACE_DIR="/var/db/postgres0/new_vwp40"
TIME='2025-05-23 00:05:54.390419+03'


pg_ctl stop

rm -rf "$TABLESPACE_DIR"
mkdir -p "$TABLESPACE_DIR"
chown -R "$PGUSER":postgres "$TABLESPACE_DIR"
rm -rf "$PGDATA"/*
mkdir -p "$PGDATA"
chown -R "$PGUSER":postgres "$PGDATA"

chmod 700 "$PGDATA"

tar -xzf "$BACKUP_DIR/$BACKUP_FILE/base.tar.gz" -C "$PGDATA"
tar -xzf "$BACKUP_DIR/$BACKUP_FILE/pg_wal.tar.gz" -C "$ARCHIVE_DIR"
mv -n "$WAL"/* "$ARCHIVE_DIR"

tar -xzf "$BACKUP_DIR/$BACKUP_FILE/16385.tar.gz" -C "$TABLESPACE_DIR"

rm -rf "$PGDATA"/pg_tblspc/*
rm -f "$PGDATA"/pg_tablespace_map/*
ln -s "$TABLESPACE_DIR" "$PGDATA"/pg_tblspc/16385

CONF="$PGDATA/postgresql.conf"
sed -i '' '/^[[:space:]]*#*[[:space:]]*archive_mode/d' "$CONF"
sed -i '' '/^[[:space:]]*#*[[:space:]]*archive_command/d' "$CONF"
sed -i '' '/^[[:space:]]*#*[[:space:]]*recovery_target_timeline/d' "$CONF"
sed -i '' '/^[[:space:]]*#*[[:space:]]*recovery_target_time/d' "$CONF"
sed -i '' '/^[[:space:]]*#*[[:space:]]*restore_command/d' "$CONF"


cat >> "$CONF" <<EOF
archive_mode = 'off'
archive_command = ''
restore_command= 'cp $ARCHIVE_DIR/%f %p'
recovery_target_time = '$TIME'
recovery_target_action = 'promote'
EOF

rm -rf $PGDATA/postgresql.auto.conf
touch $PGDATA/recovery.signal

chown -R $PGUSER:postgres $PGDATA
chmod 700 $PGDATA
pg_ctl start
  
  
```  

Выполнив который получаем восстановление базы до состояния до удаления таблиц

```shell
[postgres0@pg155 ~]$ ./recovery_wal.sh
waiting for server to shut down..... done
server stopped
waiting for server to start....2025-05-22 22:04:27.037 GMT [59709] LOG:  skipping missing configuration file "/var/db/postgres0/tah70/postgresql.auto.conf"
2025-05-23 01:04:27.114 MSK [59709] LOG:  redirecting log output to logging collector process
2025-05-23 01:04:27.114 MSK [59709] HINT:  Future log output will appear in directory "log".
 done
server started
[postgres0@pg155 ~]$ psql -U postgres0 fargoldcity -p 9136
psql (16.4)
Type "help" for help.

fargoldcity=# select * from test_table;
 id |  name
----+---------
  1 | Alice
  2 | Bob
  3 | Charlie
  4 | David
  5 | Eve
  6 | Frank
  7 | Grace
  8 | one
  9 | two
 10 | three
(10 rows)

fargoldcity=#
```

<details>
<summary>Пруфы скринами</summary>
<img src="images/drop.png" alt="Скриншот" />
<img src="images/rec_3.png" alt="Скриншот" />
</details>  

---

## Вывод

В ходе выполнения лабораторной работы была настроена система резервного копирования и восстановления базы данных. Причем
несколькими способами. Создание базовых бэкапов для восстановления базы данных из WAL файлов вообще не было очевидным
пунктом, из-за чего было потрачено очень много нервов и самообладания на то, чтобы не расплакаться. Но теперь я знаю об
этом и умею восстанавливать базы двумя способами. Таким образом, данная лабораторная работы была полезной.