###用户行为记录###
test -d /usr/lib/.cmdlog || (mkdir -p /usr/lib/.cmdlog && chmod 777 /usr/lib/.cmdlog)
chmod 777 /usr/lib/.cmdlg
export CMDLOG_FILE="/usr/lib/.cmdlog/cmdlog.$(date +%F)"
readonly PROMPT_COMMAND='{ date "+%y-%m-%d %T ##### $(who am i |awk "{print \$1\" \"\$2\" \"\$5}") #### $(pwd) #### $(history 1 | { read x cmd; echo "$cmd"; })"; } >>$CMDLOG_FILE'
