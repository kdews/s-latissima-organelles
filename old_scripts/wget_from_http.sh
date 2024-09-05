## wget me out of here:
## Index files in https-based website for faster downloading

# Required variables in conf file:
#links=
#user=
#pass=
#dir_pref=
#index=
#filenames=
#log=

# Source conf file (first arg.)
if [[ $# -eq 0 ]]; then
  echo "Error — no config file provided."
  exit 1
fi
source $1

# Append directory prefix to variables and create outdir
index=${dir_pref}/$index
filenames=${dir_pref}/$filenames
log=${dir_pref}/$log
mkdir -p $dir_pref

# Print variable values to stdout
echo "links=$links
user=$user
pass=$pass
dir_pref=$dir_pref
index=$index
filenames=$filenames
log=$log"

# Create index of each directory and parse out all filenames
> $filenames
for link in $(cat $links)
do
  echo "

Creating index for link: $link" >> $log
  wget --no-check-certificate -k -l 0 --user=$user \
--password=$pass $link -O $index >> $log
  grep "^<a href" $index | sed 's/.*href="//g' | \
sed 's/">.*//g' >> $filenames
done

# Download files
for file in $(cat $filenames)
do
  wget -P $dir_pref --no-check-certificate \
--user=$user --password=$pass $file >> $log
done

