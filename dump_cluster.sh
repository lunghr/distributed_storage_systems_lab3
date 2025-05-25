#!/usr/local/bin/bash

pg_dumpall -U postgres0 -p 9136 | gzip
