<?php
class Q
{
  /**
   * Constructor
   * @param string  $Table
   * @param string  $Fields
   * @param integer $Database
   */
  function __construct($Table='', $Fields = '*', $Database = 0, $TableName  = '')
  {
    $this->FieldsRaw = $Fields;

    if (!empty($Table))
    {
      $this->SetTable($Table);
    }
    if (!empty($TableName))
    {
      $this->SetTableName($TableName);
    }
    else
    {
      $this->SetTableName($Table);
    }

    //$this->SetFields($Fields);

    $this->Database  = intval($Database);

    $db=0;

    //Set Database Settings
    $this->Conf[$db]['Host']     = $GLOBALS['Conf']['Database']['Host'];
    $this->Conf[$db]['Username'] = $GLOBALS['Conf']['Database']['Username'];
    $this->Conf[$db]['Password'] = $GLOBALS['Conf']['Database']['Password'];
    $this->Conf[$db]['Database'] = $GLOBALS['Conf']['Database']['Database'];

    if (!isset($GLOBALS['Factory'][$this->Database]))
    {
      $this->Connect();
    }
  }

  /**
   * Connect to the selected database
   */
  function Connect()
  {
    if (empty($this->Conf[$this->Database]))
    {
      throw new SqlException('No Database selected: '.$this->Database);
    }

    if (!isset($GLOBALS['Factory'][$this->Database]['Connection']) ||
        (isset($GLOBALS['Factory'][$this->Database]['Connection']) && !is_resource($GLOBALS['Factory'][$this->Database]['Connection']))
       )
    {
      $GLOBALS['Factory'][$this->Database]['Connection'] =
        mysqli_connect($this->Conf[$this->Database]['Host'],
                       $this->Conf[$this->Database]['Username'],
                       $this->Conf[$this->Database]['Password'],
                       $this->Conf[$this->Database]['Database']
                       )
         or
        $this->Error('MySQL connect failed',mysqli_connect_error())
      ;
    }
  }

  /**
   * Sets the table name that we will use in AS in the query
   * @param string $TableName
   */
  function SetTableName($TableName='')
  {
    if ($TableName != $this->TableName)
    {
      $this->TableName = $TableName;
      $this->SetFields($this->FieldsRaw);
    }

    return $this;
  }

  /**
   * Get the table name that we will use in AS in the query
   * @param string $TableName
   */
  function GetTableName()
  {
    return $this->TableName;
  }

  /**
   * Set the Table
   * @param string $Table
   */
  function SetTable($Table='')
  {
    if ($Table != $this->Table)
    {
      $this->Table = $Table;
    }

    return $this;
  }

  /**
   * Get the Table
   * @param string $Table
   */
  function GetTable()
  {
    return $this->Table;
  }

  /**
   * Set Fields that we need to use in the query
   * @param string $Fields
   */
  function SetFields($Fields = '*')
  {
    if (!$Fields)
    {
      return $this;
    }

    $TableName = $this->GetTableName().'.';

    if ($Fields !== '*')
    {
      if (is_array($Fields))
      {
        array_walk($Fields, function (&$item, $key) use ($TableName) {
          if (!is_numeric($key))
          {
            if (strstr($key, '.') || strstr($key, 'MATCH') || strstr($key, 'COUNT') || strstr($key, 'ROUND'))
            {
              $TableName = '';
            }

            $item = $TableName.trim($key).' AS `'.trim($item).'`, ';
          }
          else
          {
            $item = $TableName.trim($item).', ';
          }
        });

        $Fields = substr(join(' ', $Fields), 0, -2);
      }
      else
      {
        $Split  = explode(', ', $Fields);
        $Fields = '';
        for ($i=0, $MaxFields = count($Split); $i < $MaxFields; ++$i)
        {
          $Fields .= $TableName.trim($Split[$i]).', ';
        }
        $Fields = substr($Fields, 0, -2);
      }
    }
    elseif ($Fields === '*' && $TableName)
    {

      $Fields = $TableName.$Fields;
    }

    if ($Fields !== $this->Fields)
    {
      if ($this->Fields === false)
      {
        $this->Fields = '';
      }

      $this->Fields .= $Fields;
    }

    return $this;
  }

  /**
   * Get Fields
   */
  function GetFields()
  {
    return $this->Fields;
  }

  /**
   * Execute an raw query
   * @param string  $Query
   * @param boolean $Execute
   */
  function Sql($Query, $Execute=true)
  {
    $this->Sql = $Query;

    //Check if we need to execute the query
    if ($Execute)
    {
      return $this->ExecuteQuery();
    }
    else
    {
      return $this;
    }
  }

  /**
   * Mysql insert ID
   */
  function MysqlInsertID()
  {
    return mysqli_insert_id($GLOBALS['Factory'][$this->Database]['Connection']);
  }

  /**
   * Build the SELECT query
   */
  function BuildQuery()
  {
    //Set SynTax
    $Sql  = $this->SynTax.' ';

    if (empty($this->Fields))
    {
      $this->SetFields($this->FieldsRaw);
    }

    $Sql .= $this->Fields;

    $Sql .= ' FROM `'.$this->Table.'` AS `'.$this->GetTableName().'`';

    if ($this->Join)
    {
      $Sql .= ' '.$this->Join;
    }

    if ($this->Where)
    {
      if (substr($this->Where, -4) === 'AND ')
      {
          $Sql .= ' WHERE '.substr($this->Where, 0, -4);
      }
      elseif (substr($this->Where, -3) === 'OR ')
      {
          $Sql .= ' WHERE '.substr($this->Where, 0, -3);
      }
      else
      {
          $Sql .= ' WHERE '.$this->Where;
      }
    }

    if ($this->Group)
    {
        $Sql .= ' GROUP BY '.$this->Group;
    }

    if ($this->Having)
    {
        $Sql .= ' '.$this->Having;
    }

    if ($this->Order)
    {
        $Sql .= ' ORDER BY '.$this->Order;
    }

    if ($this->Limit)
    {
        $Sql .= ' LIMIT '.$this->Limit;
    }

    return ($this->Sql = $Sql);
  }

  /**
   * Perform an update query
   * @param mixed   $Data
   * @param string  $PrimaryKey
   * @param boolean $Limit
   * @param boolean $First
   */
  function Update($Data, $PrimaryKey='ID', $Limit=false, $First=true)
  {
    if ($PrimaryKey === 'ID')
    {
      $Limit = 1;
    }

    $Return       = array();
    $SqlUpdate    = '';
    $this->SynTax = 'UPDATE';

    $Sql = $this->SynTax.' '.$this->Table.' SET ';

    foreach ($Data as $Key => $Value)
    {
      if ( (is_array($PrimaryKey) && isset($PrimaryKey[$Key])) || $Key === $PrimaryKey)
      {
        continue;
      }

      //if ($Value) Always Execute
      {
        if (is_array($Value))
        {
          $InsertIds      = $this->Update($Value, $PrimaryKey, $Limit, false);
          $FirstInsertId  = reset($InsertIds);

          if (is_array($FirstInsertId))
          {
            $InsertId = $InsertIds;
          }
          else
          {
            $InsertId = $FirstInsertId;
          }

          array_push($Return, $InsertId);
        }
        else
        {
          if (substr($Value, 0, 1) == '`' || substr($Value, 1, 1) == '`') // strstr($Value, '`'))
          {
            $SqlUpdate   .= ' `'.$Key.'` = '.strval($Value).', ';
          }
          else
          {
            $SqlUpdate   .= ' `'.$Key.'` = \''.self::RealEscape(strval($Value), $this->Database).'\', ';
          }
        }
      }
    }

    if (empty($SqlUpdate))
    {
      if ($this->Debug)
      {
        $this->DebugRender('SqlUpdate was empty!');
      }
      return $Return;
    }

    $SqlUpdate   = substr($SqlUpdate, 0, -2);

    if (is_array($PrimaryKey))
    {
      $Where = '';
      foreach ($PrimaryKey as $Key => $Value)
      {
        $Where .= $Key." = '".self::RealEscape($Value, $this->Database) ."' AND ";
      }

      $Where = substr($Where, 0, -5);

      if (!empty($Where))
      {
        $Sql   .= $SqlUpdate.' WHERE '.$Where;
      }

    }
    elseif (isset($Data[$PrimaryKey]))
    {
      $Sql   .= $SqlUpdate.' WHERE `'.$PrimaryKey.'` = "'.$this-> RealEscape($Data[$PrimaryKey], $this->Database).'"';
    }

    if ($Limit)
    {
      $Sql   .= ' LIMIT '.$Limit;
    }

    $this->Sql = $Sql;

    if ($this->Debug)
    {
      $this->DebugRender($this->Sql);
    }

    $Return[] = $this->ExecuteQuery();

    if ($First)
    {
      return (count($Return) === 1 ? reset($Return) : $Return);
    }

    return $Return;
  }

  /**
   * Delete row(s)
   * @param array $Delete Optional where
   */
  function Delete($Delete=false)
  {
    $this->SynTax = 'DELETE';

    $Sql  = $this->SynTax;
    $Sql .= ' FROM `'.$this->Table.'`';

    if ($this->Where)
    {
      $this->Where = str_replace($this->GetTableName().'.', '', $this->Where);

      if (substr($this->Where, -4) === 'AND ')
      {
          $Sql .= ' WHERE '.substr($this->Where, 0, -4);
      }
      elseif (substr($this->Where, -3) === 'OR ')
      {
          $Sql .= ' WHERE '.substr($this->Where, 0, -3);
      }
      else
      {
          $Sql .= ' WHERE '.$this->Where;
      }
    }

    if ($this->Limit)
    {
      $Sql   .= ' LIMIT '.$this->Limit;
    }

    $this->Sql = $Sql;

    if ($this->Debug)
    {
      $this->DebugRender($this->Sql);
    }

    return $this->ExecuteQuery();
  }

  /**
   * Perform an insert
   * @param mixed $Data
   */
  function Insert($Data)
  {
    $Return       = array();
    $this->SynTax = 'INSERT INTO';

    $Sql = $this->SynTax.' `'.$this->Table.'`';

    $SqlKeys   = '';
    $SqlValues = '';
    foreach ($Data as $Key => $Value)
    {
      //if (!empty($Value)) Always execute
      {
        if (is_array($Value))
        {
          $InsertIds      = $this->Insert($Value);
          $FirstInsertId  = reset($InsertIds);

          if (is_array($FirstInsertId))
          {
            $InsertId = $InsertIds;
          }
          else
          {
            $InsertId = $FirstInsertId;
          }

          array_push($Return, $InsertId);

        }
        else
        {
          $SqlKeys   .= ' `'.$Key.'`, ';
          $SqlValues .= ' \''.self::RealEscape($Value, $this->Database).'\', ';
        }
      }
    }

    $SqlKeys   = substr($SqlKeys, 0, -2);
    $SqlValues = substr($SqlValues, 0, -2);

    if (empty($SqlKeys) && empty($SqlValues)) {
      return $Return;
    }

    $Sql .= ' ('.$SqlKeys.' ) ';
    $Sql .= 'VALUES ('.$SqlValues.' ) ';

    $this->Sql = $Sql;

    if ($this->Debug)
    {
      $this->DebugRender($this->Sql);
    }

    $this->ExecuteQuery();
    $Return[] = mysqli_insert_id($GLOBALS['Factory'][$this->Database]['Connection']);

    if (count($Return) === 1)
    {
      return reset($Return);
    }

    return $Return;
  }

  /**
   * Fetch the query results and reterun an nice array
   * @param [type] $Resource
   */
  function Fetch($Resource)
  {
    if (isset($GLOBALS['Factory'][$this->Database]['Query'][md5($this->Sql)]))
    {
      return $GLOBALS['Factory'][$this->Database]['Query'][md5($this->Sql)];
    }

    if (is_object($Resource))
    {
      $Rows = array();
      while ($Row = mysqli_fetch_assoc($Resource))
      {
        $Rows[] = array_map(array($this, 'UTF8'), $Row);
      }

      mysqli_free_result($Resource);

      if (count($Rows) === 0)
      {
        return false;
      }

      if ($this->Limit === 1 && count($Rows) === 1)
      {
        $GLOBALS['Factory'][$this->Database]['Query'][md5($this->Sql)] = $Rows[0];
        return $Rows[0];
      }

      $GLOBALS['Factory'][$this->Database]['Query'][md5($this->Sql)] = $Rows;
      return $Rows;
    }
    else
    {
      throw new SqlException('No Fetch resource');
    }

    return false;
  }

  /**
   * FetchAll date that the query has returned
   */
  function FetchAll()
  {
    $this->BuildQuery();

    return $this->Fetch($this->ExecuteQuery());
  }

  /**
   * Fetch One item that the query has returned
   */
  function FetchOne()
  {
    $this->Limit = 1;
    $this->BuildQuery();

    return $this->Fetch($this->ExecuteQuery());
  }

  /**
   * Return the number of rows of the executed query
   */
  function Rows($NoBuild=false)
  {
    if (!$NoBuild)
    {
      $this->BuildQuery();
    }

    return mysqli_num_rows($this->ExecuteQuery());
  }

  /**
   * Describe Table
   */
  function Describe()
  {
    $this->Sql = 'DESCRIBE '.$this->GetTable();

    return $this->Fetch($this->ExecuteQuery());
  }

  /**
   * Return describe as string
   * @param array $Columns Describe array
   */
  function DescribeToString($Columns=false)
  {
    if (!$Columns)
    {
      $Columns = $this->Describe();
    }

    $String = 'array('.PHP_EOL;

    foreach($Columns as $Field)
    {
      $String .= "  array(".PHP_EOL;
      $String .= "    'Field'   => '".$Field['Field']."',".PHP_EOL;
      $String .= "    'Type'    => '".$Field['Type']."',".PHP_EOL;
      $String .= "    'Null'    => '".$Field['Null']."',".PHP_EOL;
      $String .= "    'Key'     => '".$Field['Key']."',".PHP_EOL;
      $String .= "    'Default' => '".$Field['Default']."',".PHP_EOL;
      $String .= "    'Extra'   => '".$Field['Extra']."'".PHP_EOL;
      $String .= "  ),";
    }

    $String = substr($String, 0, -1).PHP_EOL;

    $String .= ');'.PHP_EOL;

    return $String;
  }

  /**
   * Perform an Join
   * @param string $Table
   * @param string $Match
   * @param string $MatchMain
   */
  function Join($Table, $Match, $MatchMain)
  {
    $MainTableName = $this->GetTableName();

    if (is_a($Table, 'Q'))
    {
      $QM         = $Table;
      $TableName  = $QM->GetTableName();
      $Fields     = $QM->GetFields();
      $Table      = $QM->GetTable();
    }
    else
    {
      $TableName = $this->GetTableName();
      $Fields    = '*';
    }

    $this->Join .= 'LEFT JOIN '.$Table;

    if ($TableName)
    {
      $this->Join .= ' AS '.$TableName;
    }

    $this->Join .= ' ON ('.$TableName.'.'.$Match.' = '.$this->GetTableName().'.'.$MatchMain.') ';

    if ($this->Fields === '')
    {
      $this->Fields = $Fields;
    }
    else
    {
      $this->Fields .= ', '.$Fields;

    }

    return $this;
  }

  /**
   * Add Where conditions
   * @param mixed   $Field
   * @param string  $Condition
   * @param string  $Seperator
   * @param string  $Tag
   * @param string  $Operator
   */
  function Where($Field, $Condition=false, $Seperator='AND', $Tag=false, $Operator='=')
  {
    $Where    = '';
    $Prefix   = $this->GetTableName().'.';

    if (is_array($Field))
    {
      foreach ($Field as $Conditions)
      {
        if (is_array($Conditions))
        {
          $Where .= (isset($Conditions[3]) && $Conditions[3] === '(' ? $Conditions[3] : '');
          $Where .= " ".(!strstr($Conditions[0], /* $this->GetTableName().*/'.') ? $Prefix : '');
          $Where .= $Conditions[0]." ".$Operator." '".self::RealEscape($Conditions[1], $this->Database)."' ";
          $Where .= (isset($Conditions[3]) && $Conditions[3] === ')' ? $Conditions[3] : '');
          $Where .= ' '.(!isset($Conditions[2]) ? $Conditions[2] : $Seperator);
        }
        else
        {
          $Where .= (isset($Tag) && $Tag === '(' ? $Tag : '');
          $Where .= " ".(!strstr($Conditions[0], /* $this->GetTableName().*/'.') ? $Prefix : '');
          $Where .= $Field." ".$Operator." '".self::RealEscape($Conditions, $this->Database)."' ";
          $Where .= (isset($Tag) && $Tag === ')' ? $Tag: '');
          $Where .= ' '.$Seperator;
        }
      }
    }
    else
    {
      $Where .= ($Tag && $Tag === '(' ? $Tag : '');
      if (func_num_args() === 1)
      {
        $Where .= " ".$Field." ";
      }
      else
      {
        $Where .= ' '.(!strstr($Field, /* $this->GetTableName().*/'.') ? $Prefix : '');
        $Where .= $Field.' '.$Operator.' \''.self::RealEscape($Condition, $this->Database).'\' ';
      }
      $Where .= ($Tag && $Tag === ')' ? $Tag : '');

      $Where .= ($Seperator === 'AND' ? 'AND' : 'OR');
    }

    if (!empty($Where))
    {
      $this->Where .= $Where.' ';
    }

    return $this;
  }

  /**
   * Setup an Betweet
   * @param string $Field  field1
   * @param string $Field2 field2
   * @param string $Field3 field3
   */
  function Between($Field, $Field2, $Field3)
  {
    $Where    = ' '.$Field.' BETWEEN `'.$Field2.'` AND `'.$Field3.'`';

    $this->Where .= $Where.' ';

    return $this;
  }

  /**
   * Set an Group by field for in the query
   * @param boolean $Group
   */
  function Group($Group=false)
  {
    if ($Group)
    {
      if (strstr($Group, '.'))
      {
        $this->Group = $Group;
      }
      else
      {
        $this->Group = $this->GetTableName().'.'.$Group;
      }
    }

    return $this;
  }

  /**
   * Set query ORDER BY ASC
   * @param string $Order
   */
  function OrderByAsc($Order=false, $NoTableName=false)
  {
    if (!$NoTableName)
    {
      $Order = $this->GetTableName().'.'.$Order;
    }

    return $this->Order($Order, 'ASC');
  }

  /**
   * Set query ORDER BY DESC
   * @param string $Order
   */
  function OrderByDesc($Order=false, $NoTableName=false)
  {
    if (!$NoTableName)
    {
      $Order = $this->GetTableName().'.'.$Order;
    }

    return $this->Order($Order, 'DESC');
  }

  /**
   * Set query ORDER BY RAND
   * @param integer $Limit Random rows to return
   */
  function OrderByRand($Limit=1)
  {
    //Set limit
    $this->Limit(intval($Limit));

    $this->Order = 'RAND()';

    return $this->FetchAll();
    /*
      performance test
    //http://jan.kneschke.de/projects/mysql/order-by-rand/
    $this->BuildQuery();

    $Rows   = $this->Fetch($this->ExecuteQuery());
    if (!$Rows)
    {
      return false;
    }

    if ($Limit === 1)
    {
      return $Rows[array_rand($Rows, $Limit)];
    }

    if (!is_array($Rows) || count($Rows) < $Limit)
    {
      return $Rows;
    }

    $Return = array();
    $RandomRows = array_rand($Rows, $Limit);
    for ($r=0, $MaxRandomRows = count($RandomRows); $r < $MaxRandomRows; ++$r)
    {
      $Return[] = $Rows[$RandomRows[$r]];
    }

    return $Return;
    */
  }

  /**
   * Set query ORDER BY
   * @param string $Order
   * @param string  $Sort
   */
  function Order($Order=false, $Sort='DESC')
  {
    if ($Order)
    {
      if (is_array($Order))
      {
        $this->Order = '';
        foreach ($Order as $OrderSort)
        {
            $this->Order .= $OrderSort[0].' '.$OrderSort[1].', ';
        }

        $this->Order = substr($this->Order, 0, -2);
      }
      else
      {
        $this->Order = $Order.' '.$Sort;
      }
    }

    return $this;
  }

  /**
   * Set an having
   * @param string  $Having    Set the relevance coloumn
   * @param float   $Relevance Set the relevance amount
   */
  function Having($Having=false, $Relevance='0.2')
  {
    if ($Having)
    {
      $this->Having = 'HAVING '.$Having.' > '.$Relevance;
    }

    return $this;
  }

  /**
   * Set the query limit
   * @param string $Limit
   */
  function Limit($Limit=false)
  {
    if ($Limit)
    {
      if (is_array($Limit))
      {
        $this->Limit = intval($Limit[0]).', '.intval($Limit[1]);
      }
      else
      {
        $this->Limit = intval($Limit);
      }
    }

    return $this;
  }

  /**
   * Set the execute time display
   * @param string $ExecuteTime
   */
  function GetExecuteTime($ExecuteTime=false)
  {
    $this->ExecuteTime = $ExecuteTime;

    return $this;
  }

  /**
   * Return the Profile of the execution time of the query
   */
  public function Profile()
  {
    return $this->Profile;
  }

  /**
   * Execute the generated query
   */
  function ExecuteQuery()
  {
    if (empty($this->Sql))
    {
      throw new SqlException('SQL is leeg');
    }

    if (isset($GLOBALS['Factory'][$this->Database]['Query'][md5($this->Sql)]))
    {
      return true;
    }

    if (!isset($GLOBALS['Factory'][$this->Database]['Connection']) || !is_resource($GLOBALS['Factory'][$this->Database]['Connection']))
    {
      unset($GLOBALS['Factory'][$this->Database]['Connection']);
      $this->Connect();
    }

    if ($this->ExecuteTime)
    {
      mysqli_query($GLOBALS['Factory'][$this->Database]['Connection'], 'SET profiling=1');
    }

    $Resource = mysqli_query($GLOBALS['Factory'][$this->Database]['Connection'], $this->Sql) or
                mysqli_query($GLOBALS['Factory'][$this->Database]['Connection'], $this->Sql) or
                mysqli_query($GLOBALS['Factory'][$this->Database]['Connection'], $this->Sql) or
                $this->Error($this->Sql, mysqli_error($GLOBALS['Factory'][$this->Database]['Connection']));

    if ($this->ExecuteTime)
    {
      mysqli_query($GLOBALS['Factory'][$this->Database]['Connection'], 'SET profiling=0');

      $SqlProfile       = mysqli_query($GLOBALS['Factory'][$this->Database]['Connection'], ($this->ExecuteTime === 1 ? 'SHOW PROFILES' : 'SHOW PROFILE') );
      $this->Profile    = $this->Fetch($SqlProfile);
    }

    if ($this->Debug)
    {
      $this->DebugRender($this->Sql);
    }

    return $Resource;
  }

  /**
   * Get the generated query
   */
  function GetQuery()
  {
    return $this->Sql;
  }

  /**
   * Return real escaped string
   * @param string $String
   */
  static function RealEscape($String='', $Database=0)
  {
    $String = mysqli_real_escape_string($GLOBALS['Factory'][$Database]['Connection'], $String);
    //$String = htmlspecialchars($String);
    //$String = addslashes($String);
    return $String;
  }

  /**
   * Set the debug mode
   * @param string $Debug
   */
  function Debug($Debug=false)
  {
    $this->Debug = $Debug;

    return $this;
  }

  /**
   * Render the data in debug mode
   * @param mixed $Data
   */
  function DebugRender($Data)
  {
    //Check if debug mode is on and if we are allowed to see the debug output
    if ( !$GLOBALS['Conf']['Debug']['Mode'] || (isset($_SERVER['REMOTE_ADDR']) && !in_array($_SERVER['REMOTE_ADDR'], $GLOBALS['Conf']['Debug']['Allowed'])) )
    {
      return $this;
    }

    if ($this->Debug === 1)
    {
      print_r($Data);
    }
    else
    {
      if (class_exists('fb'))
      {
        fb::group($this->ClassName);
        switch ($this->Debug)
        {
          case 2:
            fb::info($Data);
            break;
          case 3:
            fb::warn($Data);
            break;
          case 4:
            fb::error($Data);
            break;
          default:
            fb::log($Data);
        }
        fb::GroupEnd();
      }
    }

    return $this;
  }

  /**
   * Check if string is UTF-8 else encode it
   * @param string $String
   */
  function UTF8($String='')
  {
    return (mb_detect_encoding($String, 'UTF-8', true) ? $String : utf8_encode($String));
  }

  /**
   * Clear class data to start fresh
   */
  function Clear()
  {
    $this->FieldsRaw   = '';
    $this->Fields      = '';
    $this->Sql         = '';
    $this->SynTax      = 'SELECT';
    $this->Join        = false;
    $this->Update      = false;
    $this->Insert      = false;
    $this->Where       = false;
    $this->Group       = false;
    $this->Order       = false;
    $this->Limit       = '';
    $this->Debug       = false;
    $this->ExecuteTime = false;
    $this->Profile     = '';
    $this->Having      = false;

    return $this;
  }

  /**
   * throw an error
   * @param string $Message
   * @param string $Error
   */
  function Error($Message='', $Error='')
  {
    if (isset($_SERVER['REMOTE_ADDR']) && !in_array($_SERVER['REMOTE_ADDR'], $GLOBALS['Conf']['Security']['AllowedIps']))
    {
      echo $Error.'<br /><br />';
      echo $Message.'<br />';
    }

    throw new SqlException($Message.' :'.$Error);
  }

  /**
   * Add an error
   * @param string $Error
   * @param string $ClassName
   * @param string $FunctionName
   */
  static function AddError($Error='', $ClassName='', $FunctionName='')
  {
    self::$Errors[] = array(
      'ClassName'    => $ClassName,
      'FunctionName' => $FunctionName,
      'Error'        => $Error
    );

    return new self();
  }

  /**
   * Send the error to the programmer
   */
  static function SendErrors()
  {
    //Check if the errors array is empty
    if (empty(self::$Errors))
    {
      return false;
    }

    $headers  = 'MIME-Version: 1.0' . PHP_EOL;
    $headers .= 'Content-type: text/html; charset=iso-8859-1' . PHP_EOL;
    $headers .= 'FROM: Qclass@'.$GLOBALS['Conf']['Webshop']['ShortUrl'].PHP_EOL;

    $Message = 'De volgende errors zijn gemaakt op '.date('d-m-Y H:i:s').':<br />';
    foreach (self::$Errors as $Error)
    {
      $Message .= '<div style="width: 619px; height: 213px;">'.print_r($Error,1).'</div><br />';

      if (isset($_SERVER))
      {
        $Message .= '<div style="width: 619px; height: 213px;">'.print_r($_SERVER,1).'</div><br />';
      }

      if (isset($_SESSION))
      {
        $Message .= '<div style="width: 619px; height: 213px;">'.print_r($_SESSION,1).'</div><br />';
      }

      $Message .= '<div style="width: 619px; height: 213px;">'.print_r(debug_backtrace(),1).'</div><br />';
    }

    mail('danny@kaboemprogrammeurs.nl', $GLOBALS['Conf']['Webshop']['Name']." Q", $Message, $headers);
  }

  public function ConnectionLink()
  {
    if (!isset($GLOBALS['Factory'][$this->Database]['Connection']))
    {
      return false;
    }

    return $GLOBALS['Factory'][$this->Database]['Connection'];
  }

  /**
   * If you call want to execute an function
   * only when the first param is true
   * @param  string $Name
   * @param  array $Arguments
   * @return mixed
   */
  public function __call($Name, $Arguments)
  {
    if (strtolower(substr($Name, 0, 2)) === 'if' && method_exists($this, ($Method = substr($Name, 2, strlen($Name)))))
    {
      if ($Arguments[0])
      {
        unset($Arguments[0]);
        return call_user_func_array(array($this, $Method), $Arguments);
      }

      return $this;
    }
    elseif (strtolower(substr($Name, 0, 4)) === 'when' && method_exists($this, ($Method = substr($Name, 4, strlen($Name)))))
    {
      if ($Arguments[0] == $Arguments[1])
      {
        unset($Arguments[0], $Arguments[1]);
        return call_user_func_array(array($this, $Method), $Arguments);
      }

      return $this;
    }

    trigger_error("Couldn't find method {$Name}", E_USER_ERROR);
    return false;
  }

  /**
   * Execute the Q shutdown
   */
  function Disconnect()
  {
    //mysqli_free_result($Resource);
    Qshutdown();

    return $this;
  }

  /**
   * Destructor
   */
  function __destruct()
  {
    Qshutdown();
  }

  // Private class variables
  private $TableName   = '',
          $Table       = '',
          $FieldsRaw   = '',
          $Fields      = '',
          $Database    = 0,
          $Conf        = array(),
          $Sql         = '',
          $SynTax      = 'SELECT',
          $Join        = false,
          $Update      = false,
          $Insert      = false,
          $Where       = false,
          $Group       = false,
          $Order       = false,
          $Limit       = '',
          $Debug       = false,
          $ExecuteTime = false,
          $Profile     = '',
          $Having      = false,
          $ClassName   = 'Q'
  ;

  // Private class variables
  public static $Errors = array();
}

class SqlException extends Exception
{
  // Protected class variables
  protected $message, $code, $Previous;

  /**
   * Constructor
   * @param  string  $message
   * @param  integer $code
   * @param  mixed  $previous
   * @return mixed
   */
  function _construct($message = null, $code = 0, Exception $previous = null)
  {
    $this->message  =  $message;
    $this->code     =  $code;
    $this->previous =  $previous;

    return parent::_construct($message, $code, $previous);
  }

  /**
   * Make Class string
   * @return string
   */
  function __toString()
  {
    Q::AddError('<b>Error</b>: '.  $this->message);

    header('HTTP/1.1 500 Internal Server Error');
    return "Er is een foutmelding op getreden, we hebben onze programmeurs hiervan op de hoogte gesteld\n\nProbeer het later nog eens.\n";
  }
}

/**
 * Q Shutdown function
 * This function will:
 * Close the MysqlI connection
 * Send the errors
 */
function Qshutdown()
{
  if (isset($GLOBALS['Factory']) && is_array($GLOBALS['Factory']))
  {
    foreach ($GLOBALS['Factory'] as $Factory)
    {
      Q::SendErrors();
      mysqli_close($Factory['Connection']);
    }

    unset($GLOBALS['Factory']);
  }
}

// Set the shutdown function
register_shutdown_function('Qshutdown');

//Set the Factory array
$Factory        = array();

/**
 * Q function
 * Make an factory object of the Q
 * @param string  $Table
 * @param string  $Fields
 * @param integer $Database
 */
function Q($Table='', $Fields = '*', $Database = 0)
{
  if (empty($Table))
  {
    return new Q($Table, $Fields, $Database);
  }

  if (isset($GLOBALS['Factory'][$Database]['Class'][$Table]))
  {
    return $GLOBALS['Factory'][$Database]['Class'][$Table]
      ->Clear()
      ->SetFields($Fields)
    ;
  }

  return ($GLOBALS['Factory'][$Database]['Class'][$Table] = new Q($Table, $Fields, $Database));
}

/**
 * QM function
 * Make an factory object of the QM QueryModel
 * @param string  $Table
 * @param string  $Fields
 * @param integer $Database
 */
function QM($Model='', $Fields = '*', $Database = 0)
{
  if (empty($Model))
  {
    return new Q($Model, $Fields, $Database);
  }

  $ClassName = $Model;
  if (!class_exists($ClassName))
  {
    throw new SqlException('Model doesnt exists: '.$Model);
    return false;
  }

  if (isset($GLOBALS['Factory'][$Database]['Model'][$Model]))
  {
    return $GLOBALS['Factory'][$Database]['Model'][$Model]
      ->Clear()
      ->SetFields($Fields)
    ;
  }

  return ($GLOBALS['Factory'][$Database]['Model'][$Model] = new $ClassName($Fields));
}
?>
