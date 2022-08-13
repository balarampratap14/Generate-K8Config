#!/bin/bash

sa_ns="service-account-ns"

# Ansi color code variables
red="\e[0;91m"
blue="\e[0;94m"
expand_bg="\e[K"
blue_bg="\e[0;104m${expand_bg}"
red_bg="\e[0;101m${expand_bg}"
green_bg="\e[0;102m${expand_bg}"
green="\e[0;92m"
white="\e[0;97m"
bold="\e[1;33m"
bold_r="\e[1;31m"
bold_g="\e[1;32m"
bold_b="\e[1;94m"
bold_w="\e[1;97m"
uline="\e[4m"
reset="\e[0m"
seperate="\e[4;36m"
hline="\e[42m"

helpFunction()
{
   echo ""
   printf "Usage: ${bold_g}$0${reset} ${bold}-u <user-email>${reset}  or ${bold_g}$0${reset} ${bold}-g <namespace's seperated with comma>${reset} " 
   exit 1 # Exit script after printing help
}
create_ns () 
{
   printf "Namespace '${bold_r}$1${reset}' doesn't exist, Creating Namespace '${bold_g}$1${reset}'"
   kubectl create ns $1 2>&1
   status=$?
   [ $status -eq 0 ] && printf "Namespace '${bold}$1${reset}' creation ${bold_g}SUCCESSFULLY.${reset}" || printf "Namespace '${bold_r}$1${reset}' creation ${bold_r}FAILED.${reset}\n"
}
check_ns ()
{
   kubectl get ns | grep ^"$1 " >/dev/null 2>&1
   status=$?
   # [ $status -eq 0 ] && printf "\nNamespace '${bold}$1${reset}' already exist." 
   [ $status -eq 1 ] && printf "\nNamespace '${bold}$1${reset}' ${bold_r}doesn't ${reset}exist! \n${bold_r}Exiting!${reset}\n" && exit 1 #create_ns $namespace
}

create_sa()
{
	kubectl create sa $1 -n $2 >/dev/null 2>&1
   #kubectl label sa $1 owner="$3" -n $2 
   return 0
}

check_sa ()
{
   kubectl get sa -n $2 | grep ^"$1 " >/dev/null 2>&1
   status=$?
   [ $status -eq 0 ] && printf "\nSA '${bold}$1${reset}' already exist in ns ${bold}$2${reset}.${reset}" && return 0
   [ $status -eq 1 ] && read -p "$(printf "\nSA '${bold}$1${reset}' ${bold_r}doesn't ${reset}exist! Do you want to create one ${bold_r}(y/n)${reset}? ")" sa_create
   if [[ $sa_create == 'y' || $sa_create == 'Y' ]]; 
   then
      create_sa $1 $2 $3
      status=$?
   	[ $status -eq 0 ] && printf "\n${bold_g}Service Account '${bold}$1${reset}' created SUCCESSFULLY in ns '${bold}$2${reset}'${reset}." && return 0 
   else
   	  exit 1 
   fi
}

create_context()
{
   cat >> src/config <<EOF 
- context:
    cluster: self-hosted-cluster
    namespace: NAMESPACE 
    user: custom-{VARIABLE}-service-account   
  name: CONTEXT
EOF
   perl -i -pe"s/NAMESPACE/${1}/g" ./src/config
   perl -i -pe"s/{VARIABLE}/${2}/g" ./src/config
   perl -i -pe"s/CONTEXT/${3}/g" ./src/config
   return 0
}

assign_label()
{
   count=$(kubectl get sa --show-labels $1 -n $2 | awk 'FNR == 2 { print $4 }' | grep -o -w "role[[:digit:]]" | wc -l)
   count=`expr $count + 1`
   #echo $count
   if [[ "$count" == 1 ]]; then
      kubectl label sa $sa_name role$count=$3 -n $2 >/dev/null 2>&1
      printf "\nserviceaccount/${bold}$sa_name${reset} ${bold_g}Labeled${reset}."
      return 0
   fi
   labels=$(kubectl get sa $1 -n $2 --show-labels | awk 'FNR == 2 { print $4 }')
   sub=$3
   # tmp=$(echo "$labels" | perl -pne 's/\s+/,/g')
   IFS=','
   read -ra ARR <<< "$labels"
   exist=0
   for i in "${ARR[@]}"; do   # access each element of array
      IFS='='
      read -ra label <<< "$i"
      if [[ "${label[1]}" == "$sub" ]]; then
            exist=1
            break
      else  
            exist=2
      fi
   done
   if [[ ${exist} == 1 ]]; then
         printf "\nserviceaccount/${bold}$sa_name${reset} already ${bold_g}Labeled${reset}."
         return 0
   else  
         kubectl label sa $sa_name role$count=$3 -n $2 >/dev/null 2>&1
         printf "\nserviceaccount/${bold}$sa_name${reset} ${bold_g}Labeled${reset}."
         return 0
   fi
}

validate_helm()
{
	kubectl get role -n $1 | grep ^"$2 " >/dev/null 2>&1
	status1=$?
	kubectl get rolebinding -n $1 | grep ^"$3 " >/dev/null 2>&1
	status2=$?
	#echo "$status1:$status2"
	[[ status1 -eq 0 && status2 -eq 0 ]] && printf "\nComponents Validation ${bold_g}SUCCESSFULL.${reset}" || printf "\nSome or all components(SA/Role/Rolebinding) ${red}FAILED${reset} to install/create."
}

validate_email()
{
   echo "$1" | grep '^.*@koireader.com$' >/dev/null 2>&1
   return $?

}

verify_role()
{
	printf "\nVerifying Role '${bold}$2${reset}' existance in namespace '${bold}$1${reset}'."
   echo ""
	kubectl get role -n $1 | grep ^"$2 " >/dev/null 2>&1
	status1=$?
	#echo "$status:$status1:$status2"
	[[ status1 -eq 0 ]] && return 1 || return 0
}

verify_rolebinding()
{
   printf "\nVerifying RoleBinding '${bold}$2${reset}' existance in namespace '${bold}$1${reset}'."
   kubectl get rolebinding -n $1 | grep ^"$2 " >/dev/null 2>&1
	status2=$?
   [[ status2 -eq 0 ]] && return 1 || return 0
}

verify_apiserver()
{
   API_SERVER=$(kubectl config view --minify | grep server | cut -f 2- -d ":" | tr -d " " )
   read -p "$(printf "\nDo you want to proceed with '${bold_r}$API_SERVER${reset}' cluster ${bold_r}(y/n)${reset}? ")" proceed
   if [[ $proceed == 'y' || $proceed == 'Y' ]]; then
      printf "Proceeding with cluster '${bold_g}$API_SERVER${reset}'."
   else
      exit 1
   fi

}

check_arg()
{
   if [ $1 -gt 2 ]; then
      printf "\n${red}Passed more than one command-line-argument, Try Again!${reset}";
      exit 1
   fi
}

create_gitlab_role()
{
   check_arg $3
   verify_apiserver
   IFS=',' #setting space as delimiter  
   read -ra ADDR <<<"$1" #reading str as an array as tokens separated by IFS  
   for x in "${ADDR[@]}"; #accessing each element of array  
   do
      check_ns $x
      sa_name=gitlab-$x-service-account
      echo ""
      check_sa $sa_name $x
      echo ""
      printf "\n${bold_b}\nCreating Gitlab_Role under ${reset} \nSA: '${bold}$sa_name${reset}' \nNamespace: '${bold}$x${reset}'"
      mkdir -p ./tmp/
      cp -f ./src/gitlab-role.yml  ./tmp/gitlab-role.yml
      cp -f ./src/rolebinding.yml  ./tmp/rolebinding.yml

    	perl -i -pe"s/gitlab_role_name$/Gitlab-Role/g" ./tmp/gitlab-role.yml
      perl -i -pe"s/gitlab_role_namespace$/$x/g" ./tmp/gitlab-role.yml
      kubectl apply -f ./tmp/gitlab-role.yml >/dev/null 2>&1
      status=$?
      echo ""
      [[ status -eq 0 ]] && printf "\nrole.rbac.authorization.k8s.io/${bold}Gitlab-Role${reset} ${bold_g}configured${reset}."  || printf "\nrole.rbac.authorization.k8s.io/${bold}Gitlab-Role${reset} configuration ${bold_r}FAILED${reset}."
      perl -i -pe"s/rolebinding_name$/Gitlab-RoleBinding/g" ./tmp/rolebinding.yml
      perl -i -pe"s/rolebinding_namespace$/$x/g" ./tmp/rolebinding.yml
      perl -i -pe"s/rolebinding_role_name$/Gitlab-Role/g" ./tmp/rolebinding.yml
      perl -i -pe"s/service_account_name$/$sa_name/g" ./tmp/rolebinding.yml
      perl -i -pe"s/rolebinding_sa_namespace$/$x/g" ./tmp/rolebinding.yml
      kubectl apply -f ./tmp/rolebinding.yml >/dev/null 2>&1
      status1=$? 
      [[ status -eq 0 ]] && printf "\nrolebinding.rbac.authorization.k8s.io/${bold}Gitlab-RoleBinding${reset} ${bold_g}configured${reset}."  || printf "\nrolebinding.rbac.authorization.k8s.io/${bold}Gitlab-RoleBinding configuration ${reset} ${bold_g}FAILED${reset}."
    	echo ""
      [[ $status -eq 0 && $status1 -eq 0 ]] && printf "\nRole and Rolebinding creation ${bold_g}SUCCESSFULL.${reset}" || $(printf "\nRole and Rolebinding creation ${red}FAILED.${reset}"; exit 1)
    	validate_helm $x "Gitlab-Role" "Gitlab-RoleBinding"
      status=$?
   	[[ $status -eq 0 ]] && assign_label $sa_name $x Gitlab-$x
      echo ""
      printf "\n${seperate}<< ================================================================================================ >> ${reset}"
      echo ""
      rm -rf ./tmp/
      printf "\n${bold_b}Generating CONFIG gitlab-$x-config!!${reset}"
      cp -f ./src/temp-config  ./kubeconfig/gitlab-$x-config
      SECRET_NAME=$(kubectl -n $x get serviceaccount/${sa_name} -o jsonpath='{.secrets[0].name}')
      TOKEN=$(kubectl get secret $SECRET_NAME -n $x -o jsonpath='{.data.token}' | base64 --decode )
      perl -i -pe"s/custom/gitlab/g" ./kubeconfig/gitlab-$x-config
      perl -i -pe"s/{VARIABLE}/$x/g" ./kubeconfig/gitlab-$x-config
      perl -i -pe"s/NAMESPACE/$x/g" ./kubeconfig/gitlab-$x-config
      #sed -i "s#NAMESPACE#${namespace}#g" ./src/config
      status=$?
      perl -i -pe"s/TOKEN/${TOKEN}/g" ./kubeconfig/gitlab-$x-config
      #sed -i "s#TOKEN#${TOKEN}#g" ./src/config
      status1=$?
      #perl -i -pe"s/API_SERVER/${API_SERVER}/g" ./src/config
      #perl -i -pe"s/API_SERVER/${API_SERVER}/g" ./kubeconfig/gitlab-$x-config
      sed -i "s#API_SERVER#${API_SERVER}#g" ./kubeconfig/gitlab-$x-config || sed -i'.bak' -e "s#API_SERVER#${API_SERVER}#g" ./kubeconfig/gitlab-$x-config 
      rm -rf ./kubeconfig/*.bak 
      status2=$?
      [[ $status -eq 0 && $status1 -eq 0 && $status2 -eq 0 ]] && printf "\nVariables substitution ${bold_g}SUCCESSFULL${reset}." || $(printf "\nVariable substitution ${bold_r}FAILED${reset}."; exit 1)

      ## To enable certificate-authority 

      #ca=$(kubectl config view --raw --flatten --minify | grep "certificate-authority")
      ca=$(kubectl config view --raw --flatten --minify | grep "certificate-authority-data")
      #prefix="certificate-authority-data: "
      #ca=$(echo $ca | sed -e "s/^$prefix//")
      stat=$?
      [ $stat -eq 0 ] && echo -e "\nCertificate-Authority ${bold_g}FOUND${reset}.\n${bold_b}Inserting into Config.${reset}" || echo -e "\nCertificate-authority ${bold_r}NOT FOUND.${reset}\nExiting! ${reset} " 
      [ $stat -ne 0 ] && exit 1
      #ca=$(echo "${ca//\//\\\/}")
      sed -i "/certificate-authority.*/s/.*/$ca/" ./kubeconfig/gitlab-$x-config || sed -i'.bak' -e "/certificate-authority.*/s/.*/$ca/" ./kubeconfig/gitlab-$x-config

      printf "\nConfig creation ${bold_g}SUCCESSFULL${reset}! \n\nConfig available at path '${bold}./kubeconfig/gitlab-$x-config${reset}' !!"
      echo ""
      printf "\n${bold_b}Encoding Config to ${bold_g}base64${reset} !! ${reset}"
      echo ""
      cat ./kubeconfig/gitlab-$x-config | base64 | awk 'BEGIN{ORS="";} {print}' 
      echo ""
      printf "\n${seperate}<< ================================================================================================ >> ${reset}"
   done
   echo ""
   printf "\n${hline}\n\t\t\t\t\t\t\t\t\t ${bold_w}ALL DONE ${reset}${reset}\n"
   exit 1
}

while getopts "u:g:" opt
do
   case "$opt" in
      u ) name="$OPTARG" && email=$name;;
      g ) namespaces="$OPTARG" && create_gitlab_role $namespaces $sa_ns $# ;;
      ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done

check_arg $#
validate_email $name
status=$?
if [ $status -eq 0 ]; then
   printf "Email Validation ${bold_g}SUCCESSFULL.${reset}"  
   name=$(echo $name | cut -d@ -f1) 
else
  printf "Email Validation ${bold_r}FAILED!${reset} Try Again with valid email of pattern ${bold_b}{ .*@koireader.com }${reset} "
  echo "" 
  exit 1  
fi

verify_apiserver
sa_name=custom-$name-service-account

pre_check()
{
   check_ns $1
   echo ""
   check_sa $2 $1 $4
}

echo ""
read -p "$(printf "\nEnter ${bold_b}multiple namespace${reset} with comma '${bold_g},${reset}' as seperator: " )" ns
IFS=',' #setting space as delimiter  

read -ra ADDR <<<"$ns" #reading str as an array as tokens separated by IFS  
  
for z in "${ADDR[@]}"; #accessing each element of array  
do  
	printf "${bold_b}\nGiving access to namespace${reset}: '${bold}$z${reset}'"
   check_ns $z
   pre_check $sa_ns $sa_name $name $email
   echo ""
   printf "\nChoose a role you want to assign to SA '${bold}$sa_name${reset}' in namespace '${bold}$z${reset}':\n" 
   prompt=$(printf "\nEnter your choice ${bold}[${reset} ${bold_g}1${reset} ${bold}-${reset} ${bold_r}4${reset} ${bold}]${reset}: ")
   PS3=${prompt}
	options=("Admin-Role" "Dev-Role" "Log-Role" "Done")
	select opt in "${options[@]}"
	do
	   case $opt in
	        "Admin-Role")
               mkdir -p ./tmp/
               printf "${bold_b}\nCreating Admin_Role under ${reset} \nSA: '${bold}$sa_name${reset}' \nNamespace: '${bold}$z${reset}' "
               echo ""
               # verify_role $i "Admin-Role" 
               # status=$? 
    			   # [ $status -eq 0 ] && role_create=true || role_create=false
               # verify_rolebinding $i "Admin-RoleBinding"
               # status=$? 
    			   # [ $status -eq 0 ] && rolebinding_create=true || rolebinding_create=false
               # #echo "$role_create:$rolebinding_create"
               cp -f ./src/admin-role.yml  ./tmp/admin-role.yml
               cp -f ./src/rolebinding.yml  ./tmp/rolebinding.yml

               perl -i -pe"s/admin_role_name$/Admin-Role/g" ./tmp/admin-role.yml
               perl -i -pe"s/namespace$/$z/g" ./tmp/admin-role.yml
               kubectl apply -f ./tmp/admin-role.yml >/dev/null 2>&1
               status=$?
               echo ""
               [[ status -eq 0 ]] && printf "\nrole.rbac.authorization.k8s.io/${bold}Admin-Role${reset} ${bold_g}configured${reset}."  || printf "\nrole.rbac.authorization.k8s.io/${bold}Admin-Role${reset} configuration ${bold_r}FAILED${reset}."
               perl -i -pe"s/rolebinding_name$/Admin-RoleBinding/g" ./tmp/rolebinding.yml
               perl -i -pe"s/rolebinding_namespace$/$z/g" ./tmp/rolebinding.yml
               perl -i -pe"s/rolebinding_role_name$/Admin-Role/g" ./tmp/rolebinding.yml
               perl -i -pe"s/service_account_name$/$sa_name/g" ./tmp/rolebinding.yml
               perl -i -pe"s/rolebinding_sa_namespace$/$sa_ns/g" ./tmp/rolebinding.yml
               kubectl apply -f ./tmp/rolebinding.yml >/dev/null 2>&1
               status1=$? 
               [[ status -eq 0 ]] && printf "\nrolebinding.rbac.authorization.k8s.io/${bold}Gitlab-RoleBinding${reset} ${bold_g}configured${reset}."  || printf "\nrolebinding.rbac.authorization.k8s.io/${bold}Gitlab-RoleBinding configuration ${reset} ${bold_g}FAILED${reset}."
               echo ""
               [[ $status -eq 0 && $status1 -eq 0 ]] && printf "\nRole and Rolebinding creation ${bold_g}SUCCESSFULL.${reset}" || $(printf "\nRole and Rolebinding creation ${red}FAILED.${reset}"; exit 1)
               validate_helm $z "Admin-Role" "Admin-RoleBinding"
               status=$?
               [[ $status -eq 0 ]] && assign_label $sa_name $sa_ns Admin-$z
               rm -rf ./tmp/
               echo ""
               printf "\n${seperate}<< ================================================================================================ >> ${reset}"
	            ;;
	        "Dev-Role")
               mkdir -p ./tmp/
               printf "${bold_b}\nCreating Dev-Role under ${reset} \nSA: '${bold}$sa_name${reset}' \nNamespace: '${bold}$z${reset}' "
               echo ""
               # verify_role $i "Dev-Role"
               # status=$? 
    			   # [ $status -eq 0 ] && role_create=true || role_create=false
               # verify_rolebinding $i "Dev-RoleBinding"
               # status=$? 
    			   # [ $status -eq 0 ] && rolebinding_create=true || rolebinding_create=false
    			   cp -f ./src/dev-role.yml  ./tmp/dev-role.yml
               cp -f ./src/rolebinding.yml  ./tmp/rolebinding.yml

               perl -i -pe"s/dev_role_name$/Dev-Role/g" ./tmp/dev-role.yml
               perl -i -pe"s/namespace$/$z/g" ./tmp/dev-role.yml
               kubectl apply -f ./tmp/dev-role.yml >/dev/null 2>&1
               status=$?
               echo ""
               [[ status -eq 0 ]] && printf "\nrole.rbac.authorization.k8s.io/${bold}Dev-Role${reset} ${bold_g}configured${reset}."  || printf "\nrole.rbac.authorization.k8s.io/${bold}Dev-Role${reset} configuration ${bold_r}FAILED${reset}."
               perl -i -pe"s/rolebinding_name$/Dev-RoleBinding/g" ./tmp/rolebinding.yml
               perl -i -pe"s/rolebinding_namespace$/$z/g" ./tmp/rolebinding.yml
               perl -i -pe"s/rolebinding_role_name$/Dev-Role/g" ./tmp/rolebinding.yml
               perl -i -pe"s/service_account_name$/$sa_name/g" ./tmp/rolebinding.yml
               perl -i -pe"s/rolebinding_sa_namespace$/$sa_ns/g" ./tmp/rolebinding.yml
               kubectl apply -f ./tmp/rolebinding.yml >/dev/null 2>&1
               status1=$? 
               [[ status -eq 0 ]] && printf "\nrolebinding.rbac.authorization.k8s.io/${bold}Dev-RoleBinding${reset} ${bold_g}configured${reset}."  || printf "\nrolebinding.rbac.authorization.k8s.io/${bold}Dev-RoleBinding configuration ${reset} ${bold_g}FAILED${reset}."
               echo ""
               [[ $status -eq 0 && $status1 -eq 0 ]] && printf "\nRole and Rolebinding creation ${bold_g}SUCCESSFULL.${reset}" || $(printf "\nRole and Rolebinding creation ${red}FAILED.${reset}"; exit 1)
               validate_helm $z "Dev-Role" "Dev-RoleBinding"
               status=$?
               [[ $status -eq 0 ]] && assign_label $sa_name $sa_ns Dev-$z
               rm -rf ./tmp/
               echo ""
               printf "\n${seperate}<< ================================================================================================ >> ${reset}"
	            ;;
	        "Log-Role")
	            mkdir -p ./tmp/
               printf "${bold_b}\nCreating Log-Role under ${reset} \nSA: '${bold}$sa_name${reset}' \nNamespace: '${bold}$z${reset}' "
               echo ""
               # verify_role $i "Log-Role"
               # status=$? 
    			   # [ $status -eq 0 ] && role_create=true || role_create=false
               # verify_rolebinding $i "Log-RoleBinding"
               # status=$? 
    			   # [ $status -eq 0 ] && rolebinding_create=true || rolebinding_create=false
    			   cp -f ./src/log-role.yml  ./tmp/log-role.yml
               cp -f ./src/rolebinding.yml  ./tmp/rolebinding.yml

               perl -i -pe"s/log_role_name$/Log-Role/g" ./tmp/log-role.yml
               perl -i -pe"s/namespace$/$z/g" ./tmp/log-role.yml
               kubectl apply -f ./tmp/log-role.yml >/dev/null 2>&1
               status=$?
               echo ""
               [[ status -eq 0 ]] && printf "\nrole.rbac.authorization.k8s.io/${bold}Log-Role${reset} ${bold_g}configured${reset}."  || printf "\nrole.rbac.authorization.k8s.io/${bold}Log-Role${reset} configuration ${bold_r}FAILED${reset}."
               perl -i -pe"s/rolebinding_name$/Log-RoleBinding/g" ./tmp/rolebinding.yml
               perl -i -pe"s/rolebinding_namespace$/$z/g" ./tmp/rolebinding.yml
               perl -i -pe"s/rolebinding_role_name$/Log-Role/g" ./tmp/rolebinding.yml
               perl -i -pe"s/service_account_name$/$sa_name/g" ./tmp/rolebinding.yml
               perl -i -pe"s/rolebinding_sa_namespace$/$sa_ns/g" ./tmp/rolebinding.yml
               kubectl apply -f ./tmp/rolebinding.yml >/dev/null 2>&1
               status1=$? 
               [[ status -eq 0 ]] && printf "\nrolebinding.rbac.authorization.k8s.io/${bold}Log-RoleBinding${reset} ${bold_g}configured${reset}."  || printf "\nrolebinding.rbac.authorization.k8s.io/${bold}Log-RoleBinding configuration ${reset} ${bold_g}FAILED${reset}."
               echo ""
               [[ $status -eq 0 && $status1 -eq 0 ]] && printf "\nRole and Rolebinding creation ${bold_g}SUCCESSFULL.${reset}" || $(printf "\nRole and Rolebinding creation ${red}FAILED.${reset}"; exit 1)
               validate_helm $z "Log-Role" "Log-RoleBinding"
               status=$?
               [[ $status -eq 0 ]] && assign_label $sa_name $sa_ns Log-$z
               rm -rf ./tmp/
               echo ""
               printf "\n${seperate}<< ================================================================================================ >> ${reset}"
	            ;;
	        "Done")
               echo ""
               printf "${seperate}<< ================================================================================================ >> ${reset}"
	            break
	            ;;
	        *) echo "invalid option $REPLY";;
	   esac
	done
done

echo ""
printf "${bold_b}Generating CONFIG $name-config!!${reset}"
cp -f ./src/temp-config  ./kubeconfig/$name-config
SECRET_NAME=$(kubectl -n $sa_ns get serviceaccount/${sa_name} -o jsonpath='{.secrets[0].name}')
TOKEN=$(kubectl get secret $SECRET_NAME -n $sa_ns -o jsonpath='{.data.token}' | base64 --decode )
perl -i -pe"s/{VARIABLE}/${name}/g" ./kubeconfig/$name-config
perl -i -pe"s/NAMESPACE/${sa_ns}/g" ./kubeconfig/$name-config
#sed -i "s#NAMESPACE#${namespace}#g" ./src/config
status=$?
perl -i -pe"s/TOKEN/${TOKEN}/g" ./kubeconfig/$name-config
#sed -i "s#TOKEN#${TOKEN}#g" ./src/config
status1=$?
#perl -i -pe"s/API_SERVER/${API_SERVER}/g" ./src/config
sed -i "s#API_SERVER#${API_SERVER}#g" ./kubeconfig/$name-config || sed -i'.bak' -e "s#API_SERVER#${API_SERVER}#g" ./kubeconfig/$name-config  
status2=$?
[[ $status -eq 0 && $status1 -eq 0 && $status2 -eq 0 ]] && printf "\nVariables substitution ${bold_g}SUCCESSFULL${reset}." || printf "\nVariable substitution ${bold_r}FAILED${reset}."

## To enable certificate-authority 

# ca=$(kubectl config view | grep "certificate-authority")
# stat=$?
# [ $stat -eq 0 ] && echo "Found certificate-authority, Inserting into Config." || echo "No certificate-authority for cluster found. Exiting .... " 
# [ $stat -ne 0 ] && exit 1
# ca=$(echo "${ca//\//\\\/}")
#sed -i "/certificate-authority.*/s/.*/$ca/" ./src/config || sed -i'.bak' -e "/certificate-authority.*/s/.*/$ca/" ./src/config
ca=$(kubectl config view --raw --flatten --minify | grep "certificate-authority-data")
stat=$?
echo ""
[ $stat -eq 0 ] && echo -e "\nCertificate-Authority ${bold_g}FOUND${reset}.\n${bold_b}Inserting into Config.${reset}" || echo -e "\nCertificate-authority ${bold_r}NOT FOUND.${reset}\nExiting! ${reset} " 
[ $stat -ne 0 ] && exit 1
sed -i "/certificate-authority.*/s/.*/$ca/" ./kubeconfig/$name-config || sed -i'.bak' -e "/certificate-authority.*/s/.*/$ca/" ./kubeconfig/$name-config
rm -rf ./kubeconfig/*.bak 
printf "\nConfig creation ${bold_g}SUCCESSFULL${reset}! \n\nConfig available at path '${bold}./kubeconfig/$name-config${reset}' !!"
echo ""
printf "\n${bold_b}Encoding base64 Config!! ${reset}"
echo ""
cat ./kubeconfig/$name-config | base64 | awk 'BEGIN{ORS="";} {print}' 
echo ""
printf "${seperate}<< ================================================================================================ >> ${reset}"
echo ""
printf "${hline}\n\t\t\t\t\t\t\t\t\t ${bold_w}ALL DONE ${reset}${reset}"
echo ""
exit 0