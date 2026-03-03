for mmm in HoffSoft Gfx MyCare
do 
    cd "$mmm/cmake" 2>/dev/null
    echo -e "\C-[[32;1m$(pwd)\C-[[0m"
    git switch master
    git pull
    cd ..
    echo -e "\C-[[32;1m$(pwd)\C-[[0m"
    git switch master
    git pull
    cd ..
done

