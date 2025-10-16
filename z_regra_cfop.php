<?
class z_regra_cfop extends ws {
	public $tableName = "z_regra_cfop";

    protected function permission(){
		return '{
        	getDadosGrid: "authenticated",
            downloadDadosGrid: "authenticated",
            uploadDadosGrid: "authenticated",
            getUploadFormHtml: "authenticated"
		}';
	}

	public function getDadosGrid($p){
        $sql = $this->queryBase($p);

        $linhas = ws::bqListQuery($sql);

        $r = new stdClass();
        $r->rows = $linhas;
        $r->result = "success";

        return $r;
	}

    public function queryBase($p = null){
    	$sql = "
        	SELECT 	*
			FROM 	z_regra_cfop
            WHERE 	1 = 1
        ";

        return $sql;
    }

    public function downloadDadosGrid($p){
        $fileTemplate = "docs/layout-empty.xlsx";
        $reader = new \PhpOffice\PhpSpreadsheet\Reader\Xlsx();
        $ws = $reader->load($fileTemplate);

        $sheet = $ws->getActiveSheet();

        $sql = $this->queryBase();
        $bqRst = ws::bqrs($sql);

        // Monta um array com resultado
        $rows = [explode(",", "grupo_cfop,cfop,descricao_cfop,saida_entrada,grupo,regra")];
        foreach ($bqRst as $rowBQ) {
            $rows[] = $rowBQ;
        }

        // preenche a planilha
		$sheet->fromArray($rows, NULL, "A1");

        $writer = new \PhpOffice\PhpSpreadsheet\Writer\Xlsx($ws);

        // cria arquivo destino
        $file_path = ws::tempFile()."_".$this->tableName."_" . ".xlsx";
        $writer->save($file_path);

        $file_token = ws::prepareDownload($file_path);

        $rst->result = "success";
        $rst->file_token = $file_token;
        $rst->file_path = $file_path;

        return $rst;
    }

    public function getUploadFormHtml($p){
    	global $G_ORGANIZATION_ID;

		$token = ws::token(32);

		session_start();
		$_SESSION["upload_".$token] = '{data:\'{method: "run", class:  "custom_ws", custom_method: "uploadDadosGrid", custom_class: "z_regra_cfop" }\', g_organization_id:"'.$G_ORGANIZATION_ID.'" }';
		session_write_close();
		$rst->result = "success";
		$rst->iframe = base64_encode('<iframe border="0" style="border:0px;height:600px;width:100%" src="htm/drag_upload.php?token='.$token.'"></iframe>');

		return $rst;
    }

    public function uploadDadosGrid($p){
    	http_response_code(400);
        $rst->status = "error";

        if(isset($_FILES["file"]) || $_POST[file_content] != ""){
            if($_POST[file_content] != ""){
                $file_origin = ws::tempFile();
                $file_origin_name = $_FILES['file']['name'];
                file_put_contents($file_origin, base64_decode($_POST[file_content]));
            } else {
                $file_origin = $_FILES['file']['tmp_name'];
                $file_origin_name = $_FILES['file']['name'];
            }

            $file_extension = pathinfo($file_origin_name, PATHINFO_EXTENSION);
            $excelFileTmp = ws::tempFile().".xlsx";
            copy($file_origin, $excelFileTmp);

            $reader = new \PhpOffice\PhpSpreadsheet\Reader\Xlsx();
            $spreadsheet = $reader->load($excelFileTmp);
            $linhas = $spreadsheet->getSheet(0)->toArray();

            // validando layout
			if (implode(",", $linhas[0]) != "grupo_cfop,cfop,descricao_cfop,saida_entrada,grupo,regra") {
            	$rst->message = "Verifique o layout. Esperado: grupo_cfop,cfop,descricao_cfop,saida_entrada,grupo,regra";
                return $rst;
            }

            // removendo cabeçalho primeira linha
            unset($linhas[0]);

            // removendo dados existentes no banco
            $sql = "TRUNCATE TABLE " . $this->tableName . "; ";

            // inserindo novos dados
            $sql .= "INSERT INTO " . $this->tableName . " (
									grupo_cfop,
									cfop,
									descricao_cfop,
									saida_entrada,
									grupo,
									regra)
					 VALUES ";
            foreach ($linhas as $index => $celula) {
            	// gerando string values ex: "(xxx, xxx), (xxx, xxx)..."
            	$linhas[$index] = "('". $celula[0] . "',
									'". $celula[1] . "',
									'". $celula[2] . "',
									'". $celula[3] . "',
									'". $celula[4] . "',
									'". $celula[5] . "'
									)";
            }

            $linhas = implode(",", $linhas);
            $sql .= $linhas;
            ws::bq($sql);

            $rst = new stdclass();
            $rst->status = "ok";
            $rst->message = "Upload concluido com sucesso";
            $rst->result = "success";


            } else {
              $rst = new stdclass();
              $rst->status = "";
              $rst->message = "Erro desconhecido";
              $rst->result = "error";

            }

          if($rst->result == "success"){

            $rst->status = "success";
            http_response_code(200);

          }

          return $rst;
    }

    public function db(){
		return '[{bqCreateTable:
					{z_regra_cfop:
						{title:"Regra CFOP",
						 columns:
							{
							grupo_cfop: {title:"Grupo CFOP", type:"STRING"},
							cfop: {title:"CFOP", type:"STRING"},
							descricao_cfop: {title:"Descrição CFOP", type:"STRING"},
							saida_entrada: {title:"Saída e Entrada", type:"STRING"},
							grupo: {title:"Grupo", type:"STRING"},
							regra: {title:"Regra", type:"STRING"}
							}
						}
				 	}
                  }
				]';
	}
}
