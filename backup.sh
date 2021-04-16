#!/bin/bash
# author:Fenglu Niu
# backup

os=`uname -s`
BIN_PATH=`dirname $0`

if [ $os == "Darwin" ];then
    bak_root="写你要备份的主目录"
    bak_mysql_user=数据库用户名
    bak_mysql_pass=数据库密码
    bak_mysql_scheme="此处写你要备份的数据库名，多个用空格隔开" 
elif [ $os == "Linux" ];then
    bak_root="/data/bak"
    bak_mysql_user=数据库用户名
    bak_mysql_pass=数据库密码
    bak_mysql_scheme="此处写你要备份的数据库名，多个用空格隔开" 
fi
bak_path_mysql="$bak_root/mysql"
bak_filename_prefix="mysql-datadump-"
bak_filename_mysql="${bak_path_mysql}/${bak_filename_prefix}`date +%Y%m%d`.sql"

#在下面的数组中添加要多机备份的IP和密码，顺序要一一对应
bak_servers_host=("主机IP")
bak_servers_pass=("主机密码")
log() {
    LOG_LEVEL="INFO"
    if [ $1 == "error"  ];then
        LOG_LEVEL="ERROR"
    fi
    echo "`date "+%Y-%m-%d %H:%M:%S,%N" | cut -b 1-23` [$LOG_LEVEL]:$2"
}

log info "开始前置条件检查"
scmd_file_count=`ls -al ${BIN_PATH}| grep scmd.exp | wc -l`
if [ $scmd_file_count == 0 ];then
    log error "请将scmd.exp文件放置于跟[$0]脚本同一目录下"
    exit 1
fi
scp_file_count=`ls -al ${BIN_PATH}| grep scp.exp | wc -l`
if [ $scp_file_count == 0  ];then
    log error "请将scp.exp文件放置于跟[$0]脚本同一目录下"
    exit 1
fi
log info "前置条件检查完毕，一切正常"
log info "开始备份"
mkdir -p $bak_path_mysql
log error "第一步：导出mysql数据库"
baked_file_count=`ls -al $bak_path_mysql|grep ${bak_filename_prefix} | wc -l `
log info "移动老数据库数据文件到临时文件夹/tmp${bak_path_mysql},默认保留十天,共${baked_file_count}个"
mkdir -p /tmp$bak_path_mysql
mv ${bak_path_mysql}/${bak_filename_prefix}* /tmp$bak_path_mysql
for ((i=0; i<${#bak_servers_host[@]}; i++))
do
    expect ${BIN_PATH}/scmd.exp ${bak_servers_host[i]} ${bak_servers_pass[i]} ${bak_path_mysql}/${bak_filename_prefix}* ${bak_path_mysql}
done
log info "备份位置$bak_filename_mysql"
starttime=`date +%s%N`
mysqldump -u$bak_mysql_user -p$bak_mysql_pass --databases $bak_mysql_scheme > $bak_filename_mysql
endtime=`date +%s%N`
interval=`awk "BEGIN{printf \"%.3f\n\",($endtime-$starttime)/1000000000}"`
file_size=`ls -lh $bak_filename_mysql | awk '{print $5}'`
log info "数据库备份完成耗时${interval}s，备份文件大小：$file_size"
log info "数据库备份文件多机备份开始:"

for ((i=0; i<${#bak_servers_host[@]}; i++))
do
    log info "服务器${i+1}[${bak_servers_host[i]}]拷贝开始"
    starttime=`date +%s%N`
    expect ${BIN_PATH}/scp.exp ${bak_servers_host[i]} ${bak_servers_pass[i]} $bak_filename_mysql $bak_path_mysql
    endtime=`date +%s%N`
    interval=`awk "BEGIN{printf \"%.3f\n\",($endtime-$starttime)/1000000000}"`
    log info "服务器${i+1}[${bak_servers_host[i]}]拷贝完成耗时${interval}s"
done
