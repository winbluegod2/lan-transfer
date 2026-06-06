#!/bin/bash
# 生成 Android 签名 keystore
# 在项目根目录运行：bash scripts/create_android_keystore.sh

set -e

echo "=== 创建 Android 签名 Keystore ==="
echo ""

read -p "Key Alias (如 lan-transfer): " KEY_ALIAS
read -s -p "Keystore 密码（至少6位）: " STORE_PASS
echo ""
read -s -p "Key 密码（至少6位）: " KEY_PASS
echo ""
read -p "你的名字（英文）: " YOUR_NAME
read -p "组织名（可留空，直接回车）: " ORG
read -p "城市（英文，如 Shanghai）: " CITY
read -p "国家代码（如 CN）: " COUNTRY

keytool -genkey -v \
  -keystore android/app/keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias "$KEY_ALIAS" \
  -storepass "$STORE_PASS" \
  -keypass "$KEY_PASS" \
  -dname "CN=$YOUR_NAME, OU=${ORG:-Unknown}, O=${ORG:-Unknown}, L=$CITY, ST=$CITY, C=$COUNTRY"

# 写入 key.properties
cat > android/key.properties << EOF
storePassword=$STORE_PASS
keyPassword=$KEY_PASS
keyAlias=$KEY_ALIAS
storeFile=keystore.jks
EOF

echo ""
echo "✅ 完成！生成了："
echo "   android/app/keystore.jks   ← 妥善保管，丢失无法找回！"
echo "   android/key.properties     ← 已加入 .gitignore，不会提交到 Git"
echo ""
echo "⚠️  请备份 keystore.jks 到安全位置！"
