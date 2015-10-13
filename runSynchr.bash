#! /bin/bash

declare -r PROG="runSynchr"
declare -i nThread=5
declare -i second=300
declare -i from=1
declare -i to=-1
declare -i n=0

usage(){
	[ $# -ne 0 ] && cat <<EOF
ERROR: $@

EOF
	cat <<EOF
USAGE
	$PROG -n 5 -f 1 -t -1 task.lst

ARGUMENT
	-n INT: set the number of 'thread's
	-f, -from INT:
	-t, -to INT: set the range to run
	task.lst: one task per line
EOF
	exit 1
}
echoStatus(){
	echo "$n" > ".$$.stt";
}
update(){
	if [ -r ".$$.cfg" ]; then
		old_nThread=$nThread
		source ".$$.cfg" # dangerous! hacker leak

		[ $from -gt $n ] && n=$from
		if [ $nThread -gt $old_nThread ]; then
			for (( j = $old_nThread; j < $nThread; j ++ )); do
				echo >&6
			done
		else
			nThread=$old_nThread
		fi

	fi
}

trap 'echoStatus' USR1
trap 'update'	USR2

[ $# -eq 0 ] && usage

ARGS=`getopt -a -n runSynchr -o n:f:t:h -l nThread:,from:,to:help,man -- "$@"`
[ $? -ne 0 ] && usage
eval set -- "${ARGS}"
while true; do
	case "$1" in
	-n|--nThread)		nThread=$2; shift; ;;
	-f|--from)		from=$2; shift; ;;
	-t|--to)		to=$2; shift; ;;
	-h|--help|--man)	usage; exit 1; ;;
	--)			shift; break; ;;
	esac
shift
done

jobf=$1
[ -r $jobf ] || usage "task file is not readable."
njob=$(wc -l $jobf |cut -f1 -d' ')
[ $from -eq 0 -o $to -eq 0 ] && usage "Bad range."
[ $from -lt 0 ] && (( from = njob + from + 1 ))
[ $to -lt 0 ] && (( to = njob + to + 1 ))

tmp_fifo="/tmp/$$.fifo"
mkfifo $tmp_fifo
exec 6<>$tmp_fifo
rm $tmp_fifo
for ((i=0; i<$nThread; i++)); do echo; done >&6

n=$from
while true; do
	read -u6
	ln=$(sed -n "${n},${n}p" $jobf)
	{
		eval $ln
		echo >&6
	} &
	[ $n -eq $to -o $n -eq $njob ] && break
	(( n ++ ))
done

wait

exec 6>&-

exit 0
