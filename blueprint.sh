#!/bin/bash

VERSION="indev";

cd /var/www/pterodactyl;
if [[ "$@" == *"-php"* ]]; then
    exit 1;
fi;

mkdir .blueprint 2> /dev/null;
cp -R blueprint/* .blueprint/ 2> /dev/null;
rm -R blueprint 2> /dev/null;

source .blueprint/lib/bash_colors.sh;
source .blueprint/lib/parse_yaml.sh;
source .blueprint/lib/db.sh;

if [[ $1 != "-bash" ]]; then
    if dbValidate "blueprint.setupFinished"; then
        clr_blue "This command only works if you have yet to install Blueprint. You can run \"\033[1;94mblueprint\033[0m\033[0;34m\" instead.";
        dbRemove "blueprint.setupFinished";
        exit 1;
    else
        clr_bright "/var/www/pterodactyl/public/themes/pterodactyl/css/pterodactyl.css";
        sed -i "s!@import 'checkbox.css';!@import 'checkbox.css';\n@import url(/assets/extensions/blueprint/blueprint.style.css);!g" /var/www/pterodactyl/public/themes/pterodactyl/css/pterodactyl.css;


        clr_bright "php artisan view:clear";
        php artisan view:clear > /dev/null;


        clr_bright "php artisan config:clear";
        php artisan config:clear > /dev/null;


        clr_bright "chown -R www-data:www-data /var/www/pterodactyl/*";
        chown -R www-data:www-data /var/www/pterodactyl/* > /dev/null;

        clr_bright "chown -R www-data:www-data /var/www/pterodactyl/.*";
        chown -R www-data:www-data /var/www/pterodactyl/.* > /dev/null;

        dbAdd "blueprint.setupFinished";
        exit 1;
    fi;
fi;

if [[ $2 == "-i" ]]; then
    if [[ $3 == "" ]]; then
        clr_bright "Expected 1 argument but got 0.";
    fi;
    FILE=$3".blueprint"
    if [[ ! -f "$FILE" ]]; then
        echo "$FILE could not be found.";
        exit 1;
    fi;

    ZIP=$3".zip"
    cp $FILE .blueprint/tmp/$ZIP;
    cd .blueprint/tmp;
    unzip $ZIP;
    cd /var/www/pterodactyl;
    rm .blueprint/tmp/$ZIP;

    eval $(parse_yaml .blueprint/tmp/$3/conf.yml)
    if [[ $target != $VERSION ]]; then
        clr_red "The operation could not be completed since the target version of the extension ($target) does not match your Blueprint version ($VERSION).";
        rm -R .blueprint/tmp/$3;
        exit 1;
    fi;
    if [[ $identifier != $3 ]]; then
        clr_red "The extension identifier should be exactly the same as your .blueprint file (just without the .blueprint). This may be subject to change, but is currently required.";
        rm -R .blueprint/tmp/$3;
        exit 1;
    fi;
    if [[ $identifier == "blueprint" ]]; then
        clr_red "The operation could not be completed since the extension is attempting to overwrite internal files.";
        rm -R .blueprint/tmp/$3;
        exit 1;
    fi;

    if [[ $migrations == "yes" ]]; then
        cp -R .blueprint/tmp/$3/migrations/* database/migrations/ 2> /dev/null;
    fi;

    cp -R .blueprint/defaults/extensions/admin.default .blueprint/defaults/extensions/admin.default.bak 2> /dev/null;
    if [[ $controller != "custom" ]]; then
        cp -R .blueprint/defaults/extensions/controller.default .blueprint/defaults/extensions/controller.default.bak 2> /dev/null;
    fi;
    cp -R .blueprint/defaults/extensions/route.default .blueprint/defaults/extensions/route.default.bak 2> /dev/null;
    cp -R .blueprint/defaults/extensions/button.default .blueprint/defaults/extensions/button.default.bak 2> /dev/null;

    mkdir public/assets/extensions/$identifier;
    cp .blueprint/tmp/$3/icon.jpg public/assets/extensions/$identifier/icon.jpg;
    ICON="/assets/extensions/$identifier/icon.jpg";
    CONTENT=$(cat .blueprint/tmp/$3/admin/index.blade.php);

    sed -i "s!␀title␀!$name!g" .blueprint/defaults/extensions/admin.default.bak > /dev/null;
    sed -i "s!␀name␀!$name!g" .blueprint/defaults/extensions/admin.default.bak > /dev/null;
    sed -i "s!␀breadcrumb␀!$name!g" .blueprint/defaults/extensions/admin.default.bak > /dev/null;
    sed -i "s?␀name␀?$name?g" .blueprint/defaults/extensions/button.default.bak > /dev/null;

    sed -i "s!␀description␀!$description!g" .blueprint/defaults/extensions/admin.default.bak > /dev/null;

    sed -i "s!␀version␀!$version!g" .blueprint/defaults/extensions/admin.default.bak > /dev/null;
    sed -i "s?␀version␀?$version?g" .blueprint/defaults/extensions/button.default.bak > /dev/null;

    sed -i "s!␀icon␀!$ICON!g" .blueprint/defaults/extensions/admin.default.bak > /dev/null;

    sed -i "s!␀content␀!$CONTENT!g" .blueprint/defaults/extensions/admin.default.bak > /dev/null;

    if [[ $controller != "custom" ]]; then
        sed -i "s!␀id␀!$identifier!g" .blueprint/defaults/extensions/controller.default.bak > /dev/null;
    fi;
    sed -i "s!␀id␀!$identifier!g" .blueprint/defaults/extensions/route.default.bak > /dev/null;
    sed -i "s?␀id␀?$identifier?g" .blueprint/defaults/extensions/button.default.bak > /dev/null;

    ADMINVIEW_RESULT=$(cat .blueprint/defaults/extensions/admin.default.bak);
    ADMINROUTE_RESULT=$(cat .blueprint/defaults/extensions/route.default.bak);
    ADMINBUTTON_RESULT=$(cat .blueprint/defaults/extensions/button.default.bak);
    if [[ $controller != "custom" ]]; then
        ADMINCONTROLLER_RESULT=$(cat .blueprint/defaults/extensions/controller.default.bak);
    fi;
    ADMINCONTROLLER_NAME=$identifier"ExtensionController.php";

    mkdir resources/views/admin/extensions/$identifier;
    touch resources/views/admin/extensions/$identifier/index.blade.php;
    echo $ADMINVIEW_RESULT > resources/views/admin/extensions/$identifier/index.blade.php;

    mkdir app/Http/Controllers/Admin/Extensions/$identifier;
    touch app/Http/Controllers/Admin/Extensions/$identifier/$ADMINCONTROLLER_NAME;
    if [[ $controller != "custom" ]]; then
        echo $ADMINCONTROLLER_RESULT > app/Http/Controllers/Admin/Extensions/$identifier/$ADMINCONTROLLER_NAME;
    fi;
    if [[ $controller == "custom" ]]; then
        echo $(cat .blueprint/tmp/$3/admin/indexController.php) > app/Http/Controllers/Admin/Extensions/$identifier/$ADMINCONTROLLER_NAME;
    fi;

    echo $ADMINROUTE_RESULT >> routes/admin.php;

    sed -i "s?<!--␀replace␀-->?$ADMINBUTTON_RESULT\n<!--␀replace␀-->?g" resources/views/admin/extensions.blade.php > /dev/null;

    rm .blueprint/defaults/extensions/admin.default.bak;
    if [[ $controller != "custom" ]]; then
        rm .blueprint/defaults/extensions/controller.default.bak;
    fi;
    rm .blueprint/defaults/extensions/route.default.bak;
    rm .blueprint/defaults/extensions/button.default.bak;
    rm -R .blueprint/tmp/$3;
fi;

touch /usr/local/bin/blueprint > /dev/null;
echo -e "#!/bin/bash\nbash /var/www/pterodactyl/blueprint.sh -bash \$@;" > /usr/local/bin/blueprint;
chmod u+x /var/www/pterodactyl/blueprint.sh > /dev/null;
chmod u+x /usr/local/bin/blueprint > /dev/null;

if [[ $2 == "help" ]]; then
    echo -e "";
fi;