#!/bin/bash
#VARIABLES_BEGIN
MAIL_ADDR=jimi77.gk@gmail.com # адрес, на который шлётся отчёт
MAIL_CONTENT=""
LOCKPATH=/tmp/watchdog.lock
LOGPATH=/var/log/access.log # анализируемый лог
RUN_FLAG=/tmp/watchdog.run
STARTLINE=1
TIME_START=""
TIME_END=""
TOP_IP=10 # количество source IP
TOP_IP_S=""
TOP_RETURN_CODE=10
TOP_RETURN_CODE_S=""
TOP_RESOURCE=10 # количество ресурсов
TOP_RESOURCE_S=""
ALL_ERRORS=""
#VARIABLES_END

function finish {
    rm -f "$RUN_FLAG";
    exit 0;
}

if [[ -f $RUN_FLAG ]]; # если создан флаг, скрипт уже запущен или некорректно завершён
    then echo "!!! SCRIPT ALWAYS RUNNING OR UNSUCCESSFULY COMPLITED !!! If you're sure, delete the file /tmp/watchdog.run and run again."; exit 1;
fi

touch $RUN_FLAG # создание флага запущенного скрипта
trap finish EXIT # при нормальном завершении, при получении прерывающего сигнала, который может быть обработан удалить флаг запуска

if [[ -f $LOCKPATH ]]; # если создан якорь, лог уже анализировался
    then
        LOCK=$(cat $LOCKPATH) # считать последнюю строку с предыдущего запуска скрипта
        # если последняя строка лога не изменилась с момента последнего запуска, новые данные отсутствуют, выход
        if [ "$LOCK" == "$(tail -n 1 $LOGPATH)" ]; then finish; fi
        # найти в логе номер строки на которой закончен анализ в прошлый запуск
        STARTLINE=$( grep -n -F -s "$LOCK" $LOGPATH | grep -o '^[[:digit:]]*' );
        ((STARTLINE += 1)); # строка, с которой нужно начать анализ
        # начало периода
        TIME_START=$( tail -n +$STARTLINE $LOGPATH | head -1 | grep -o -e '\[[^\]*\]' );
        # список source IP
        TOP_IP_S=$( tail -n +$STARTLINE $LOGPATH | awk '{print $1}' | sort | uniq -c | sort -nr | head -$TOP_IP );
        # список кодов возврата
        TOP_RETURN_CODE_S=$( tail -n +$STARTLINE $LOGPATH | awk -F'"{1}[^"]*"{1}| '  '{print $8}' | sort | uniq -c | sort -nr );
        # список запрошенных ресурсов
        TOP_RESOURCE_S=$( tail -n +$STARTLINE $LOGPATH | awk -F'"'  '{print $2}' $LOGPATH | awk '$2 != "" {print $2}' | sort | uniq -c | sort -nr | head -$TOP_RESOURCE );
        # ошибки 4xx(client error), 5xx(server error)
        ALL_ERRORS=$( tail -n +$STARTLINE $LOGPATH | grep -e '" [4,5][0-9][0-9] ' )
    else
        # начало периода
        TIME_START=$( head -1 $LOGPATH | grep -o -e '\[[^\]*\]' );
        # список source IP
        TOP_IP_S=$( awk '{print $1}' $LOGPATH | sort | uniq -c | sort -nr | head -$TOP_IP );
        # список кодов возврата
        TOP_RETURN_CODE_S=$( awk -F'"{1}[^"]*"{1}| '  '{print $8}' $LOGPATH | sort | uniq -c | sort -nr );
        # список запрошенных ресурсов
        TOP_RESOURCE_S=$( awk -F'"'  '{print $2}' $LOGPATH | awk '$2 != "" {print $2}' | sort | uniq -c | sort -nr | head -$TOP_RESOURCE );
        # ошибки 4xx(client error), 5xx(server error)
        ALL_ERRORS=$( grep -e '" [4,5][0-9][0-9] ' $LOGPATH )
fi
TIME_END=$( tail -n 1 $LOGPATH | grep -o -e '\[[^\]*\]' );# конец периода
# запомнить последнюю строку в текущую итерацию скрипта для использования при последующих запусках
tail -n 1 $LOGPATH > $LOCKPATH;

# создание тела письма
read -r -d '' MAIL_CONTENT << EOM 
Server statistic by period $TIME_START - $TIME_END

TOP $TOP_IP IP:
===============
$TOP_IP_S

ALL RETURN CODES:
=================================
$TOP_RETURN_CODE_S

TOP $TOP_RESOURCE RESOURCES:
============================
$TOP_RESOURCE_S

ALL ERRORS since last run:
==========================
$ALL_ERRORS
EOM

#echo "$MAIL_CONTENT"

echo "$MAIL_CONTENT" | mailx -r "<jimidini77@yandex.ru>" \
                             -s "Server statistic" \
                             -S smtp="smtp.yandex.ru:587" \
                             -S nss-config-dir=/etc/pki/nssdb/ \
                             -S smtp-use-starttls \
                             -S smtp-auth=login \
                             -S smtp-auth-user="jimidini77@yandex.ru" \
                             -S smtp-auth-password="bkgggwpmorzhafeb" \
                             -S ssl-verify=ignore \
                             $MAIL_ADDR 2>&1

finish # очистка флага запущенного скрипта и выход
