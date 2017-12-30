#!/bin/bash

centos6_inittab() {
################### configuration runlevel ########################## 

grep "id:5:initdefault:"  /etc/inittab   >> /dev/null
 if [ $? -eq 0 ]
       then
	        sed -i  's/id\:5\:initdefault\:/id\:3\:initdefault:/g' /etc/inittab
 fi
 
}

centos6_forbidden_reboot() {
##################### forbidden contrl+alt+delete #####################

kernel=$(uname -r | awk  'BEGIN{FS="-"}{print $1}'| awk 'BEGIN{FS="."}{print $3}')
 
  if [ $kernel -ge 23 ]
      then 
	   >/etc/init/control-alt-delete.conf
      else	
           sed  -i  's/ca::ctrlaltdel:\/sbin\/shutdown\ -t3\ -r\ now/#ca::ctrlaltdel:\/sbin\/shutdown\ -t3\ -r\ now/g'  /etc/inittab
  fi 

}

centos6_close_iptables() {
###################### close firewall ##############################

chkconfig --level 35 iptables  off 
> /etc/sysconfig/iptables
/etc/init.d/iptables  stop
iptables -F  
}

centos7_close_iptables() {
###################### close firewall ##############################

systemctl stop iptables
systemctl disable iptables
systemctl stop firewalld.service
systemctl disable firewalld.service

iptables -F  
}

centos6_shutdown_service() {
################  configuration service ### close the unnecessary services ####################

chkconfig --level 35 microcode_ctl off
chkconfig --level 35 lvm2-monitor off
chkconfig --level 35 ntpd off
chkconfig --level 35 readahead_early off
chkconfig --level 35 kudzu off 
chkconfig --level 35 ip6tables off
chkconfig --level 35 iptables off
chkconfig --level 35 mcstrans off
chkconfig --level 35 isdn off
chkconfig --level 35 auditd off
chkconfig --level 35 restorecond off
chkconfig --level 35 cpuspeed off
chkconfig --level 35 irqbalance on
chkconfig --level 35 nfslock off
chkconfig --level 35 mdmonitor off
chkconfig --level 35 rpcidmapd off
chkconfig --level 35 messagebus off
chkconfig --level 35 setroubleshoot off
chkconfig --level 35 rpcgssd off
chkconfig --level 35 bluetooth off
chkconfig --level 35 netfs off
chkconfig --level 35 pcscd off
chkconfig --level 35 acpid off
chkconfig --level 35 haldaemon off
chkconfig --level 35 hidd off
chkconfig --level 35 autofs off
chkconfig --level 35 cups off
chkconfig --level 35 rawdevices off
chkconfig --level 35 sendmail off
chkconfig --level 35 gpm off
chkconfig --level 35 xfs off
chkconfig --level 35 anacron off
chkconfig --level 35 atd off
chkconfig --level 35 yum-updatesd off
chkconfig --level 35 avahi-daemon off
chkconfig --level 35 firstboot off

}

#####################  configuration local yum #####################

OSname=`cat /etc/redhat-release | awk '{print $1}'`

if [ $OSname == "CentOS" ] ;then
    OSverison=`cat /etc/redhat-release | sed 's/Linux//g' |awk '{print $3}' | cut -d . -f 1`
    case $OSverison in
          7)  mkdir -p /etc/yum.repos.d/bak
                mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/bak/
		cd /etc/yum.repos.d
                wget http://192.168.20.220/centos7/centos7.repo 
		centos7_close_iptables
          ;;
          6.5)  mkdir -p /etc/yum.repos.d/bak
                mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/bak/
		cd /etc/yum.repos.d
                wget http://192.168.20.220/centos6.5/centos6.5.repo 
		centos6_inittab
		centos6_forbidden_reboot
		centos6_close_iptables
		centos6_shutdown_service
          ;;
          *)  echo "OSverison not found"
          ;;
    esac
fi

############################   yum install ############################
yum -y install gcc gcc-c++  make openssl-devel net-snmp tcl ipmitool* nc expect  ntpdate wget vim lrzsz net-tools sysstat

yum -y update


################## configuration zonetime ###########################

 \cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
 
################## configuration ntp ###############################
    
  if [ ! -f /usr/sbin/ntpdate ]	
    then   
	 yum clean all
	 yum  -y install ntp
  fi    
  grep "192.168.20.220"  /etc/crontab  >> /dev/null  2>&1
  if [ $? -ne 0  ]
       then 
	        echo "01 * * * *  root  /usr/sbin/ntpdate 192.168.20.220; /sbin/hwclock -w" >> /etc/crontab
			/usr/sbin/ntpdate 192.168.20.220
			if [ $OSverison == 6.5 ]; then
				/etc/init.d/ntpd stop
				/etc/init.d/crond restart
			else
				systemctl stop ntpd.service
				systemctl disable ntpd.service
				systemctl restart crond.service
			fi	        
  fi

############################ modify ssh#################################
sed -i 's/GSSAPIAuthentication yes/GSSAPIAuthentication no/g' /etc/ssh/sshd_config
sed -i 's/#UseDNS yes/UseDNS no/g' /etc/ssh/sshd_config

if [ $OSverison == 6.5 ]; then
	/etc/init.d/sshd restart
else
	systemctl restart sshd.service
fi


######################### close CoreDump ####################

grep  -v  "^#" /etc/security/limits.conf | grep core  >> /dev/null  2>&1
 
if [ $? -eq  0 ] 
  then
      echo  -e "Close CoreDump           \e[32m done\e[0m"
  else 
      echo "*	soft	core	0"  >> /etc/security/limits.conf
      echo "*	hard	core	0"  >> /etc/security/limits.conf  
      echo  -e "Close CoreDump	         \e[32m done\e[0m"
 fi
 
######################  configuration open the largest number of files ###############################

 grep  -v "^#" /etc/security/limits.conf | grep nofile  >> /dev/null 2>&1
 
 if [ $? -eq 0 ]
          then 
              echo  -e "ulimited config         \e[32m done\e[0m"
	  else
	      echo "*	soft	nofile		655360" >> /etc/security/limits.conf
	      echo "*	hard	nofile		655360" >> /etc/security/limits.conf
	      echo "ulimit -u unlimited" >>/etc/profile
	      echo "ulimit -s unlimited" >>/etc/profile
	      echo "ulimit -i 514855" >>/etc/profile
	      echo "ulimit -SHn 655350" >>/etc/profile
	      source /etc/profile

 fi

####################### close SELINUX ##############################
  
sed -i               's/SELINUX=enforcing/SELINUX=disabled/g'  /etc/sysconfig/selinux 
sed -i               's/SELINUX=permissive/SELINUX=disabled/g'  /etc/sysconfig/selinux 
setenforce 0  >> /dev/null
echo  -e  "Close selinux              \e[32m done\e[0m"  


######################### configuration history record ########################

grep  logger  /etc/bashrc

          if [ $? -ne 0 ]
               then 
                  echo "logger -p local3.info  \"\`who am i\` =======================================  is login \""  >> /etc/bashrc
                  echo  "export PROMPT_COMMAND='{ msg=\$(history 1 | { read x y; echo \$y; }); logger -p local3.info  \[ \$(who am i)\]\# \""\${msg}"\"; }'"  >> /etc/bashrc
                  source /etc/bashrc
                  if  [ -f  /etc/rsyslog.conf ]
                           then
                                echo  "local3.info                        /var/log/history.log"  >> /etc/rsyslog.conf  
								if [ $OSverison == 6.5 ]; then
									/etc/init.d/rsyslog restart
								else
									systemctl restart rsyslog.service
								fi
                           else 
                                echo  "local3.info                        /var/log/history.log"  >> /etc/syslog.conf
								if [ $OSverison == 6.5 ]; then
									/etc/init.d/rsyslog restart
								else
									systemctl restart rsyslog.service
								fi
                  fi        

           fi

######################### configuration DNS ###########################

cat << EOF > /etc/resolv.conf
nameserver 114.114.114.114
nameserver 219.141.136.10 
nameserver 219.141.140.10
nameserver 202.106.0.20
nameserver 8.8.8.8
EOF


#######################  update linux  Loophole ########################
yum clean all
yum -y update glibc
yum -y update openssl
yum -y update bash

####################### profile#########################################
#sed -i '/mv/a\alias vi='\'vim'\'\'' /root/.bashrc 
#source /root/.bashrc

########################## configuration hostname ########################

#cat << EOF > /etc/sysconfig/network
#NETWORKING=yes
#EOF
#
#echo "====================================================================================="
#echo "============================ Welcome to config hostname ============================="
#echo "===================== /etc/hosts and /etc/sysconfig/network ========================="
#echo "================= format is:IP hostname (eg:10.58.50.25 S2SD001) ===================="
#echo "====================================================================================="
#read -p "please input server's IP and hostname : " IPADDR HOSTNAME 
#while [ -z $IPADDR ] || [ -z $HOSTNAME ];
#do
#           echo "the input format is wrong, please input again : IP hostname (eg:10.58.50.25 S2SD001)"
#           read -p "please input server's IP and hostname : " IPADDR HOSTNAME
#done
##sed -i "s/gomeserver/$HOSTNAME/g"  /etc/sysconfig/network
#echo "HOSTNAME=$HOSTNAME" >> /etc/sysconfig/network
#echo "$IPADDR $HOSTNAME" >> /etc/hosts
#/bin/hostname $HOSTNAME


cat << EOF > /etc/sysctl.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv4.tcp_syn_retries = 1
net.ipv4.tcp_synack_retries = 1
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.tcp_keepalive_intvl =15
net.ipv4.tcp_retries1 = 3
net.ipv4.tcp_retries2 = 5
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_tw_recycle = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_max_tw_buckets = 60000
net.ipv4.tcp_max_orphans = 32768
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.tcp_mem = 94500000 915000000 927000000
net.ipv4.tcp_wmem = 4096 16384 13107200
net.ipv4.tcp_rmem = 4096 87380 17476000
net.ipv4.ip_local_port_range = 1024 65000
net.ipv4.route.gc_timeout = 100
net.core.somaxconn = 32768
net.core.netdev_max_backlog = 32768
net.nf_conntrack_max = 6553500
net.netfilter.nf_conntrack_max = 6553500
net.netfilter.nf_conntrack_tcp_timeout_established = 180
vm.overcommit_memory = 1
vm.swappiness = 1
EOF

source /etc/profile
sysctl -p
