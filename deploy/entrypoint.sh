#!/bin/sh
set -e
# 以 schema.prisma 为准同步表结构（幂等），然后启动服务
npx prisma db push --skip-generate
exec node dist/index.js
