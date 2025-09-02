@echo off
set CF_API=https://api.cf.us10-001.hana.ondemand.com
set CF_USERNAME=你的账号
set CF_PASSWORD=你的密码
set CF_ORG=
set CF_SPACE=
set CF_APP=你的APP
echo === Login to Cloud Foundry ===
cf api %CF_API% --skip-ssl-validation
cf auth %CF_USERNAME% %CF_PASSWORD%
cf target -o %CF_ORG% -s %CF_SPACE%

echo === Try to start app ===
cf start %CF_APP%

if %errorlevel% neq 0 (
    echo Failed to start app. Trying restart...
    cf restart %CF_APP%
)

echo === Done ===
pause