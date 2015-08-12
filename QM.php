<?php

class MainCat extends Q
{
  private $TableName = 'MainCat',
          $Table     = 'MainCategorie',
          $ClassName = 'QM',
          $Database  = 0
  ;

  private $TableDescribe = array(
    array(
      'Field'   => 'ID',
      'Type'    => 'tinyint(1) unsigned',
      'Null'    => 'NO',
      'Key'     => 'PRI',
      'Default' => '',
      'Extra'   => 'auto_increment'
    ),
    array(
      'Field'   => 'Active',
      'Type'    => 'tinyint(1) unsigned',
      'Null'    => 'NO',
      'Key'     => 'MUL',
      'Default' => '0',
      'Extra'   => ''
    ),
    array(
      'Field'   => 'InMenu',
      'Type'    => 'tinyint(1) unsigned',
      'Null'    => 'NO',
      'Key'     => 'MUL',
      'Default' => '0',
      'Extra'   => ''
    ),
    array(
      'Field'   => 'Sort',
      'Type'    => 'tinyint(1) unsigned',
      'Null'    => 'NO',
      'Key'     => '',
      'Default' => '',
      'Extra'   => ''
    ),
    array(
      'Field'   => 'MainCatID',
      'Type'    => 'tinyint(1) unsigned',
      'Null'    => 'NO',
      'Key'     => 'MUL',
      'Default' => '',
      'Extra'   => ''
    ),
    array(
      'Field'   => 'MainCatName',
      'Type'    => 'varchar(24)',
      'Null'    => 'NO',
      'Key'     => '',
      'Default' => '',
      'Extra'   => ''
    ),
    array(
      'Field'   => 'MainCatTitle',
      'Type'    => 'varchar(256)',
      'Null'    => 'NO',
      'Key'     => 'MUL',
      'Default' => '',
      'Extra'   => ''
    ),
    array(
      'Field'   => 'MainCatKeywords',
      'Type'    => 'varchar(256)',
      'Null'    => 'NO',
      'Key'     => '',
      'Default' => '',
      'Extra'   => ''
    ),
    array(
      'Field'   => 'MainCatDesc',
      'Type'    => 'varchar(256)',
      'Null'    => 'NO',
      'Key'     => '',
      'Default' => '',
      'Extra'   => ''
    ),
    array(
      'Field'   => 'MainCat',
      'Type'    => 'varchar(256)',
      'Null'    => 'NO',
      'Key'     => '',
      'Default' => '',
      'Extra'   => ''
    ),
    array(
      'Field'   => 'MainCatText',
      'Type'    => 'text',
      'Null'    => 'NO',
      'Key'     => '',
      'Default' => '',
      'Extra'   => ''
    ),
    array(
      'Field'   => 'ClassName',
      'Type'    => 'varchar(24)',
      'Null'    => 'NO',
      'Key'     => '',
      'Default' => '',
      'Extra'   => ''
    ),
    array(
      'Field'   => 'ItemsARow',
      'Type'    => 'tinyint(2) unsigned',
      'Null'    => 'NO',
      'Key'     => '',
      'Default' => '10',
      'Extra'   => ''
    )
  );

  /**
   * Constructor
   * @param string  $Fields
   */
  function __construct($Fields = '*')
  {
    parent::__construct($this->Table, $Fields, $this->Database, $this->TableName);
  }
}
?>
