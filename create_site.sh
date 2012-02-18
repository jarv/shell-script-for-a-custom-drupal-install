#!/bin/bash
set -x
set -e
PROFILE="my_profile"    # profile name
P_NAME="Standard with Content Creator" 
P_DESC="Create a \"content manager\" role and user"
SN="mysite"                     # site name
SD=`dirname $0`"/$SN"           # site dir
ADMIN=  # admin name
ADMIN_PASS= # admin password
MAIL= # site/admin email
CC_USER= # content creator username
CC_PASS= # content creator password
CC_EMAIL= # content create email
DMAKE="/tmp/$$.dmake"

cat<<END >$DMAKE
; Core Drupal
; -------------
core = 7.x
api = 2
projects[drupal][version] = 7

; Modules
; -------------
projects[role_delegation][subdir] = contrib

END

if [[ -d $SD ]]; then
    chmod -R u+w $SD 
    rm -rf $SD
fi
drush make $DMAKE $SN
rm -f $DMAKE

# create the profile directory
mkdir $SD/profiles/$PROFILE
mkdir $SD/sites/default/files
cp $SD/sites/default/default.settings.php  $SD/sites/default/settings.php
chmod a+w $SD/sites/default/files
chmod a+w $SD/sites/default/settings.php

# create the .info file
cat<<END > $SD/profiles/$PROFILE/$PROFILE.info

name = $P_NAME
description = $P_DESC
version = VERSION
core = 7.x
dependencies[] = block
dependencies[] = color
dependencies[] = comment
dependencies[] = contextual
dependencies[] = dashboard
dependencies[] = help
dependencies[] = image
dependencies[] = list
dependencies[] = menu
dependencies[] = number
dependencies[] = options
dependencies[] = path
dependencies[] = taxonomy
dependencies[] = dblog
dependencies[] = search
dependencies[] = shortcut
dependencies[] = toolbar
dependencies[] = overlay
dependencies[] = field_ui
dependencies[] = file
dependencies[] = rdf
; also enabling the role delegation module
dependencies[] = role_delegation
files[] = $PROFILE.profile

; Information added by drupal.org packaging script on 2012-02-01
version = "7.12"
project = "drupal"
datestamp = "1328134560"

END

# copy and munge the standard install profile
cp $SD/profiles/standard/standard.install \
   $SD/profiles/$PROFILE/$PROFILE.install
perl -pi -e "s/standard_/${PROFILE}_/g" \
   $SD/profiles/$PROFILE/$PROFILE.install 


# create the .profile file
# "PROFILE" is the name of hte profile which will be 
# munged after it is written to disk

cat<<'END' > $SD/profiles/$PROFILE/$PROFILE.profile

<?php

/**
 * Implements hook_form_FORM_ID_alter().
 *
 * Allows the profile to alter the site configuration form.
 */
function PROFILE_form_install_configure_form_alter(&$form, $form_state) {
  // Pre-populate the site name with the server name.
  $form['site_information']['site_name']['#default_value'] = $_SERVER['SERVER_NAME'];
}

/**
 * Implements hook_install_tasks().
 */
function PROFILE_install_tasks() {
  $tasks = array();

  // Add a page allowing the user to specify a "content creator" user 
  $tasks['PROFILE_cc_form'] = array(
    'display_name' => st('Content creator username'),
    'type' => 'form',
  );

  return $tasks;
}

/**
 * Task callback: returns the form allowing the user to add
 * a "content creator" user
 */
function PROFILE_cc_form() {
  drupal_set_title(st('Content Creator Username'));

  $form['cc_uid'] = array(
    '#type' => 'textfield',
    '#title' => st('Username for Content Creator:'),
    '#description' => st('Enter the content creator userid'),
  );
  $form['cc_email'] = array(
    '#type' => 'textfield',
    '#title' => st('Email for Content Creator:'),
    '#description' => st('Enter the content creator email'),
  );
  $form['cc_pass'] = array(
    '#type' => 'textfield',
    '#title' => st('Password for Content Creator:'),
    '#description' => st('Enter the content creator password in both fields'),
  );


  $form['actions'] = array('#type' => 'actions');
  $form['actions']['submit'] = array(
    '#type' => 'submit',
    '#value' => st('Create content creator role and user'),
    '#weight' => 15,
  );
  return $form;
}

/**
 * Submit callback: creates the "content creator" role and user
 */
function PROFILE_cc_form_submit(&$form, &$form_state) {
  $uid  = $form_state['values']['cc_uid'];
  $email  = $form_state['values']['cc_email'];
  $pass  = $form_state['values']['cc_pass'];

  // Create a role for "content managers"
  $c_role = new stdClass();
  $c_role->name = 'content manager';
  $c_role->weight = 3;

  user_role_save($c_role);

  // additional permissions beyond what the authenticated
  // user receives
  user_role_grant_permissions($c_role->rid, array(
    'assign content manager role',
    'create article content',
    'edit own article content',
    'delete own article content',
    'create page content',
    'edit own page content',
    'delete own page content',
    'administer themes',
  ));
  $cc_user = array (
    'name' => $pass,
    'pass' => $pass,
    'roles' => array($c_role->rid => $c_role->rid),
    'mail' => $email,
    'status' => 1, # status: active
  );

  $user = user_save(NULL, $cc_user);
}
END

perl -pi -e "s/PROFILE/${PROFILE}/g" \
   $SD/profiles/$PROFILE/$PROFILE.profile 


cd $SD && drush -y site-install --clean-url=0 --db-url=sqlite:sites/default/files/db.sqlite --account-name=$ADMIN --account-pass=$ADMIN_PASS --account-mail=$MAIL --site-mail=$MAIL  $PROFILE ${PROFILE}_cc_form.cc_uid=$CC_USER ${PROFILE}_cc_form.cc_email=$CC_EMAIL ${PROFILE}_cc_form.cc_pass=$CC_PASS
