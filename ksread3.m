function [KSX, Header] = ksread3(file,dataBlockNo)
%--------------------------------------------------------------------------
%% ksread3
%   共和標準データファイルフォーマットKS2をMATLABで読み込みためのスクリプトファイルです。
%
%    使用法:
%    KSX          = ksread3('FileName');
%    [KSX,Header] = ksread3('FileName');
%    KSX          = ksread3('FileName',OptNo);
%    [KSX,Header] = ksread3('FileName',OptNo);
%
%      引数
%          FileName         ... 対象データファイル(拡張子含む:KS2 or E4A)
%                               E4Aファイルを指定した場合，2つ目の引数は無視されます
%          OptNo(option)    ... ブロックデータの読み込み番号または，KS2とE4Aファイルの同時読み込みモード
%                               OptNoを指定しない場合，自動的にブロック
%                               番号は1になります。
%　　　　　　　　　　　　　　　　　'-1'を指定した場合，'Filename'で指定した
%                               ファイル名と同名のE4Aファイルを同時に読み込みます
%                               同名のE4Aファイルが無い場合，KS2のみ読み込みます
%      戻り値
%          KSX              ... 時間データ含めた抽出した集録データ。
%                               [M,(time)+N]の多次元配列。
%          Header           ... CH情報(Cell配列)
%
%
%   実行時プロンプト表示情報
%   ファイルID              データを集録した製品の型式です
%   バージョン              KS2のバージョンです
%   最大データブロック数     データのブロック数です
%   指定データブロック番号   BlockNoで指定したブロック数です
%   集録CH数                アナログCH数とデジタルCH数を足したCH数です
%   個別集録CH数            アナログCH数です
%   サンプリング周波数(Hz)   データ集録時のサンプリング周波数です
%   データ集録数            1CH当たりの集録データ数です
%
%   その他：
%           いくつかのグローバル変数で処理方法が異なります。
%
%
%    global g_CsvFormat;     %ヘッダ情報のフォーマットの旧式・標準を切り替えます      0：旧タイプ  1：標準タイプ
%                                   旧タイプ：DAS-200AのVer01.05以前のCSV変換形式
%                                   標準タイプ：Ver01.06での新たなCSV変換形式
%    global g_IndexType;     %データのインデックスを切り替えます                     0：時間      1：番号
%    global g_StartNumber;   %データのインデックスの開始番号を切り替えます            0：0始まり   1：1始まり
%    global g_LanguageType;  %表示言語を切り替えます                                0:日本語     1:英語
%
%
%   Copyright 2016 Kyowa ELECTRONIC INSTRUMENTS CO.,LTD.
%   version 1.03 2016/02/19
%
%   Date 13/12/25
%   ver1.00 新規リリース
%           CAN情報読み込みに対応

%   Date 14/01/24
%   ver1.01 E4Aの読み込みに対応
%
%   Date 14/06/20
%   ver1.02 ファイルポインタの処理を修正
%           EDX-200Aで集録した際の集録開始カウンタ値がない場合の処理を追加
%           float型のデータ処理を修正
%           CANデータ処理のSigned型の不具合を修正

%   Date 16/02/19
%   ver1.03 KS2ファイルの集録開始カウンタ値の取得部を修正
%           CSV標準タイプ時，E4AとKS2を同時に読み込んだ際に測定CH数がNaNになる不具合を修正
%
%
%--------------------------------------------------------------------------

% initalized variable
%
    global g_NtbFlag;       %測定器がNTBかを示すフラグ
    global g_Ks2VerNum;     %KS2のVer情報


    global g_CsvFormat;     %ヘッダ情報形式の旧タイプ・標準タイプを切り替えます
                            %0：旧タイプ  1：標準タイプ
                            %旧タイプ：DAS-200Aの初期保存形式
                            %標準タイプ：Ver01.06で追加された新たなCSV保存形式

    global g_IndexType;     %読み込んだ集録データ行列の先頭列に付加するデータ形式を切り替えます
                            %0：時間      1：番号

    global g_StartNumber;   %読み込んだ集録データ行列の先頭列に付加するデータの先頭の開始番号を切り替えます。
                            %0：0始まり   1：1始まり

    global g_LanguageType;  %本スクリプト実行時のコマンドプロンプト上に表示する言語を切り替えます
                            %0:日本語     1:英語

    g_CsvFormat    = 0;     %旧タイプ
    g_IndexType    = 0;     %時間
    g_StartNumber  = 0;     %0始まり
    %g_LanguageType = 0;     %日本語
    g_LanguageType = 1;     %English

    tblInfo = [];

    delm = '.';

    tblInfo.Error{1}       = 'MATLAB:ksread3:FileName';
    tblInfo.Error{2}       = 'MATLAB:ksread3:Argument';
    tblInfo.Error{3}       = 'MATLAB:ksread3:Argument';
    tblInfo.Error{11}      = 'MATLAB:ksread3:FileExist';
    tblInfo.Error{12}      = 'MATLAB:ksread3:AbnormalBlockNo';
    tblInfo.Error{13}      = 'MATLAB:ksread3:AbnormalBlockNo';
    tblInfo.Error{14}      = 'MATLAB:ksread3:FileExtension';
    tblInfo.Error{15}      = 'MATLAB:ksread3:FileExist';
    tblInfo.Error{16}      = 'MATLAB:ksread3:MeasurementParameter';
    tblInfo.Error{17}      = 'MATLAB:ksread3:FileExist';
    tblInfo.Error{21}      = 'MATLAB:ksread3:OutOfMemory';
    tblInfo.Error{22}      = 'MATLAB:ksread3:Error Ocurred';
    tblInfo.err.message    = '';
    tblInfo.err.identifier = '';
    tblInfo.err.stack      = [];

    % MATLABのversionチェック
    vers = version;
    tblInfo.MATLAB_Ver   = str2double(vers(1:3));

    tblInfo.HeadSeek     = 256; % 固定長ヘッダ部の大きさ
    tblInfo.InfoSeek     = 6;
    tblInfo.FixCH        = 16;
    tblInfo.CmpExt       = 'ks2';
    tblInfo.CmpMachine1  = 'EDX-1500A';
    tblInfo.CmpMachine2  = 'PCD-300A';
    tblInfo.CmpMachine10 = 'UDAS-100A';

    % ver1.01  MATLABのVer(R2008以降)によって言語切り替えが困難のため，パラメータで設定する
    tblInfo.CmpLang = 'jhelp';
    if g_LanguageType == 0
        tblInfo.Lang = 'jhelp';
    else
        tblInfo.Lang = 'Dummy';
    end

    % (1)引数が指定されていない場合
    if nargin < 1 || isempty(file)
        error(makeDispMessage(1,tblInfo));
        exit;
    elseif nargin < 2
        dataBlockNo = 1;
    elseif nargin > 2
        % (2)引数の数が適切でない
        strMsgBuf = makeDispMessage(2,tblInfo);
        error(strMsgBuf);
        exit;
    end

    [tbls,num] = split_str(file,delm);
    % (3)拡張子が無い
    if num < 2
        tblInfo.err = tbls;
        strMsgBuf = makeDispMessage(3,tblInfo);
        error(strMsgBuf);
        exit;
    end
    tblInfo.ext = lower(tbls{2}); % 取得した拡張子

    %2番目の引数が負なら
    if(dataBlockNo < 0)
        ReadBoth = 1;
        dataBlockNo = 0;
        tblInfo.dataBlockNo = dataBlockNo;
    else
        ReadBoth = 0;
        tblInfo.dataBlockNo = dataBlockNo;
    end

    %拡張子がKS2なら
    if(strcmpi(tblInfo.CmpExt, tblInfo.ext) == 1)

        %KS2ファイルの読み込み
        fid = fopen(file,'r');
        % (11)ファイルが存在しない場合
        if fid < 0
            strMsgBuf = makeDispMessage(11,tblInfo);
            error(strMsgBuf);
            exit;
        end
        % (14)拡張子が異なる
        if(strcmpi(tblInfo.CmpExt, tblInfo.ext) == 0)
            strMsgBuf = makeDispMessage(14,tblInfo);
            error(strMsgBuf);
            exit;
        end

        %KS2よりテキスト情報の取得
        tblInfo = getInfo(fid,tblInfo);

        %ブロック番号のチェック
        if isnumeric(dataBlockNo) < 1
            % (13)指定されたブロックNoが数値ではない場合
            strMsgBuf = makeDispMessage(13,tblInfo);
            error(strMsgBuf);
            exit;
        else
            % (12)指定されたブロックNoが不正な場合
            if dataBlockNo > tblInfo.BlockNo
                strMsgBuf = makeDispMessage(12,tblInfo);
                error(strMsgBuf);
                exit;
            else
            end
        end

        %オプションに同時読み込みが設定されていなかったら
        if(ReadBoth == 0)
            ReadMode = 0;
        %同時読み込みなら
        else
            %ファイル名の拡張子をKS2→E4Aに置換
            file((strfind(file, '.') + 1):end) = 'e4a';

            %E4Aファイルが存在するか事前に確認する
            e4afid = fopen(file,'r');

            %ファイル名の拡張子をE4A→KS2に置換
            file((strfind(file, '.') + 1):end) = 'ks2';

            %E4Aファイルがないなら
            if(e4afid<0)
                ReadMode = 0;
            %E4Aファイルがあるなら
            else
                ReadMode = 2;
                fclose(e4afid);
            end
        end
    %拡張子がE4Aなら
    elseif(strcmpi('e4a', tblInfo.ext) == 1)
        ReadMode = 1;
    %KS2ファイルでもE4Aファイルではない場合
    else
        % (17)KS2ファイルでもE4Aファイルでもない場合
        strMsgBuf = makeDispMessage(17,tblInfo);
        error(strMsgBuf);
        exit;
    end

    %もしE4Aのみファイル読み込むなら
    if(ReadMode == 1)
        [KSX, Header, ErrNo] = e4read(file);
        if(ErrNo ~= 0)
            strMsgBuf = makeDispMessage(ErrNo,tblInfo);
            error(strMsgBuf);
            exit;
        end
        return;
    end

    %コマンドウィンドウに集録条件の表示
    %makeDispMessage(100,tblInfo);

    %KS2のバージョン番号の取得
    VerStr = split_str(tblInfo.version,delm);
    g_Ks2VerNum = str2double(cell2mat(VerStr(2)));

%KS2の集録開始カウンタ値の取得

    if(strcmpi(tblInfo.machine, 'EDX-200A') == 1)
        tblInfo.DataReadBody = (tblInfo.HeadSeek + tblInfo.variableHeader+tblInfo.dataHeader + 2);

        %集録データ部のボディ部バイト数までポインタを移動
        fseek(fid, tblInfo.DataReadBody,'bof');

        %ボディ部バイト数を取得
        tblInfo.DataBodyByte = fread(fid, 1,'int64=>double');

        %データフッタ部までポインタを移動
        fseek(fid, (tblInfo.DataReadBody + tblInfo.DataBodyByte + 8),'bof');

        %オフセット用のバイト数を設定
        OffsetSeek = (tblInfo.DataReadBody + tblInfo.DataBodyByte + 8);

        %集録開始カウンタ値を探査(0x12 0x19)
        while(1)
            [parent, child] = checkFlag(fid, OffsetSeek, 0);    %ver1.03

            %データフッタ部の項目が無いなら読み込み終了
            if(isempty(parent) == 1)
                tblInfo.StCnt = 0;
                break;
            end
            [SeekByte, ~]= makeSeek(fid, parent, child);

            if(parent == 18)
                if(child == 32)
                    tblInfo.StCnt = fread(fid,1,'uint64');
                    break;
                end
            end

            %大分類，小分類，項目フラグ，データ型の4バイト分を加算する
            OffsetSeek = OffsetSeek + 4;

            %ボディバイト数の型のサイズ分シーク位置を更新
            if (child == 25)
                OffsetSeek = OffsetSeek + 8;
            elseif (child == 26)
                OffsetSeek = OffsetSeek + 4;
            elseif (child == 28)
                OffsetSeek = OffsetSeek + 4;
            elseif (child == 30)
                OffsetSeek = OffsetSeek + 4;
            elseif (child == 31)
                OffsetSeek = OffsetSeek + 2;
            elseif (child == 32)
                OffsetSeek = OffsetSeek + 2;
            end

            %ボディバイト数分シーク位置を更新
            OffsetSeek = OffsetSeek + SeekByte;     %ver1.03
        end
    else
        tblInfo.StCnt = 0;
    end

    %E4AとKS2を読みこむなら
    if(ReadMode == 2)
        %ファイル名の拡張子をKS2→E4Aに置換
        file((strfind(file, '.') + 1):end) = 'e4a';

        %E4Aのヘッダ情報の取得
        tblInfoE4a = e4readHeader(file);

        %KS2とE4Aの集録条件が一致しているか確認
        if(tblInfo.StCnt ~= tblInfoE4a.StCnt)
            %(16)測定条件が異なるためKS2とE4Aファイルの互換性が無い
            strMsgBuf = makeDispMessage(16,tblInfo);
            error(strMsgBuf);
            exit;
        end

        if(tblInfo.Hz ~= tblInfoE4a.Fs)
            %(16)測定条件が異なるためKS2とE4Aファイルの互換性が無い
            strMsgBuf = makeDispMessage(16,tblInfo);
            error(strMsgBuf);
            exit;
        end

        %E4Aファイルのを読み込むためのメモリが不足していたら
        try
            %CANデータ行列をNaNで初期化
            e4X(1:tblInfoE4a.e4XLen-tblInfoE4a.StCnt,1:tblInfoE4a.TransChStsNum) = NaN;
        catch
            strMsgBuf = makeDispMessage(21,tblInfo);
            error(strMsgBuf);
            exit;
        end
            clear e4X;
    end

%各セルデータの初期化
        tblfileID = cell(1,tblInfo.chAll+1);
        tblfileID(:,:) = {''};
        %tblfileID(1,1) = {'[ID番号]'};
        tblfileID(1,1) = {'[ID No.]'};

        tblfileTitle = cell(1,tblInfo.chAll+1);
        tblfileTitle(:,:) = {''};
        %tblfileTitle(1,1) = {'[タイトル]'};
        tblfileTitle(1,1) = {'[Title]'};

        tblfileCh_num = cell(1,tblInfo.chAll+1);
        tblfileCh_num(:,:) = {''};
        %tblfileCh_num(1,1) = {'[測定CH数]'};
        tblfileCh_num(1,1) = {'[Number of Channels]'};

        tblfileSf = cell(1,tblInfo.chAll+1);
        tblfileSf(:,:) = {''};
        %tblfileSf(1,1) = {'[サンプリング周波数(Hz)]'};
        tblfileSf(1,1) = {'[Sampling Frequency (Hz)]'};

        tblfileDigi_ch = cell(1,tblInfo.chAll+1);
        tblfileDigi_ch(:,:) = {''};
        %tblfileDigi_ch(1,1) = {'[デジタル入力]'};
        tblfileDigi_ch(1,1) = {'[Digital Input]'};

        tblfileTime = cell(1,tblInfo.chAll+1);
        tblfileTime(:,:) = {''};
        %tblfileTime(1,1) = {'[測定時間(sec)]'};
        tblfileTime(1,1) = {'[Time (sec)]'};

%ID番号
        fseek(fid,0,'bof');
        header_array = fread(fid,20,'uchar');
        header_array(end-2:end,:)=[];           %"(0x22)と終端2文字CRLF(0D，0A)の削除
        header_array(1,:)=[];                   %先頭の"(0x22)の削除
        for n=1:size(header_array,1)
            if(header_array(end,1)==32)
                header_array(end,:)=[];
            else
                break;
            end
        end
        if(isempty(header_array)==0)
           tblfileID(1,2)={native2unicode(header_array)'};
        end
        clear header_array;

%タイトル
        fseek(fid,30,'bof');
        header_array = fread(fid,44,'uchar');
        header_array(end-2:end,:)=[];           %終端2文字CRLF(0D，0A)と”(0x22)
        header_array(1,:)=[];
        for n=1:size(header_array,1)
            if(header_array(end,1)==32)
                header_array(end,:)=[];
            else
                break;
            end
        end
        if(isempty(header_array)==0)
            tblfileTitle(1,2)={native2unicode(header_array)'};
        end
        clear header_array;

%測定チャンネル数
        fseek(fid,74,'bof');
        header_array = fread(fid,8,'uchar');
        header_array(end-1:end,:)=[];           %集録CH数～サンプリング周波数までは”(0x22)が無い
        for n=1:size(header_array,1)
            if(header_array(end,1)==32)
                header_array(end,:)=[];
            else
                break;
            end
        end
        if(isempty(header_array)==0)
            tblfileCh_num(1,2)={str2double(native2unicode(header_array)')};
        end
        clear header_array;

%サンプリング周波数
        fseek(fid,90,'bof');
        header_array = fread(fid,16,'uchar');
        header_array(end-2:end,:)=[];           %終端2文字CRLF(0D，0A)と”(0x22)
        for n=1:size(header_array,1)
            if(header_array(end,1)==32)
                header_array(end,:)=[];
            else
                break;
            end
        end
        if(isempty(header_array)==0)
            tblfileSf(1,2)={str2double(native2unicode(header_array)')};
        end
        clear header_array;

%可変長ヘッダ部のバイト数の抽出
        fseek(fid,176,'bof');
        header_array = fread(fid,14,'uchar');    %可変長ヘッダ部～可変長フッタ部までは”(0x22)が無い
        header_array(end-1:end,:)=[];
        for n=1:size(header_array,1)
            if(header_array(end,1)==32)
                header_array(end,:)=[];
            else
                break;
            end
        end
        if(isempty(header_array)==0)
            var_Header=str2double(native2unicode(header_array)');
        end
        clear header_array;

%ディジタル入力CH数
%可変長ヘッダ部先頭から0x01と0x2Cが連続した2バイトを探す

    for n=1:var_Header
        fseek(fid,256+n-1,'bof');
        if(fread(fid,1,'uchar')== 1)
            fseek(fid,256+n,'bof');
            if(fread(fid,1,'uchar')== 44)
                fseek(fid,4,'cof');
                lsb_b=fread(fid,1,'uchar');
                msb_b=fread(fid,1,'uchar');
                if((lsb_b == 255 && msb_b == 255) || (lsb_b == 0 && msb_b == 0))
                    tblfileDigi_ch(1,2)={'OFF'};
                elseif((1<=lsb_b && lsb_b<=10) && msb_b==0)
                    tblfileDigi_ch(1,2)={'ON('};
                    tblfileDigi_ch(1,2)={strcat(cell2mat(tblfileDigi_ch(1,2)),num2str(lsb_b),')')};
                else
                    tblfileDigi_ch(1,2)={'OFF'};
                end
                break;
            end
        end
    end

    % 集録CANCH数0を設定
    tblInfo.CanChNum = 0;

    [strRcvBuf,tblHeader, tblInfo.CanChNum] = DataRead12(fid,tblInfo);
    % 展開する配列サイズが現在使用可能なメモリ空間以上の場合
    if strRcvBuf == 999
        strMsgBuf = makeDispMessage(21,tblHeader);
        error(strMsgBuf);
        exit;
    elseif strRcvBuf == 111
        % edit at 2008/01/25 メモリ以外のエラーが発生した場合
        strMsgBuf = makeDispMessage(22,tblHeader);
        error(strMsgBuf);
        exit;
    end

    KSX = strRcvBuf;
    clear strRcvBuf;

    %CAN-CH番号分測定CH数を加算
    tblfileCh_num(1,2)={(tblInfo.CanChNum + tblInfo.chAll)};

%CANデータがある場合の処理
    if (tblInfo.CAN ~= 0)
        if(tblInfo.chAll ~= 0)
            tblfileID(      tblInfo.chAll+2:tblInfo.CanChNum+tblInfo.chAll+1)={''};
            tblfileTitle(   tblInfo.chAll+2:tblInfo.CanChNum+tblInfo.chAll+1)={''};
            tblfileCh_num(  tblInfo.chAll+2:tblInfo.CanChNum+tblInfo.chAll+1)={''};
            tblfileDigi_ch( tblInfo.chAll+2:tblInfo.CanChNum+tblInfo.chAll+1)={''};
            tblfileSf(      tblInfo.chAll+2:tblInfo.CanChNum+tblInfo.chAll+1)={''};
            tblfileTime(    tblInfo.chAll+2:tblInfo.CanChNum+tblInfo.chAll+1)={''};
        end
    end

    %測定時間の算出    データ/Chをサンプリング周期で割る
     tblfileTime(1,2)={cell2mat(tblHeader(end,2))/cell2mat(tblfileSf(1,2))};

    %チャンネル数が1CHの場合，試験日時で3セル扱うのに対し，他は2セルとなるため空の3セル目を追加

    if(tblInfo.chAll<=1)
        tblfileID(:,3)={''};
        tblfileTitle(:,3)={''};
        tblfileCh_num(:,3)={''};
        tblfileDigi_ch(:,3)={''};
        tblfileSf(:,3)={''};
        tblfileTime(:,3)={''};

        Header = [tblfileID;tblfileTitle;tblfileCh_num;tblfileDigi_ch;tblfileSf;tblHeader;tblfileTime];
    else
        Header = [tblfileID;tblfileTitle;tblfileCh_num;tblfileDigi_ch;tblfileSf;tblHeader;tblfileTime];
    end

    %旧タイプ
    if g_CsvFormat == 0
        %NTB以外
        if g_NtbFlag == 0
            Header=cat(1,Header(1:2,:),Header(end-2,:),Header(3:end,:));
            Header=cat(1,Header(1:6,:),Header(end-1:end,:),Header(7:end,:));
            Header=cat(1,Header(1:11,:),Header(15:17,:));
        %NTB
        else
            Header=cat(1,Header(1:2,:),Header(end-2,:),Header(3:end,:));
            Header=cat(1,Header(1:6,:),Header(end-1:end,:),Header(7:end,:));
            Header(19:end,:)=[];
        end
    %標準タイプ
    else
        %NTB以外
        if g_NtbFlag == 0
            Header=cat(1,Header(1:2,:),Header(end-2,:),Header(3:end,:));
            Header=cat(1,Header(1:6,:),Header(end-1:end,:),Header(7:end,:));
            Header=cat(1,Header(1:4,:),Header(6:9,:),Header(11:17,:),Header(10,:));
        %NTB
        else
            Header=cat(1,Header(1:2,:),Header(end-2,:),Header(3:end,:));
            Header=cat(1,Header(1:6,:),Header(end-1:end,:),Header(7:end,:));
            Header=cat(1,Header(1:4,:),Header(6:9,:),Header(11:18,:),Header(10,:));
        end
    end

    fclose(fid);

    clear tblfileCh_num
    clear tblfileDigi_ch
    clear tblfileID
    clear tblfileSf
    clear tblfileTime
    clear tblfileTitle
    clear tblHeader

    %E4AとKS2を読み込むなら
    if(ReadMode == 2)
        [e4X, e4Header] = e4read(file);

        %E4Aのデータ行列の長さを取得
        [e4M,~] = size(e4X);

        %KS2のデータ行列の長さを取得
        [ksM,ksN] = size(KSX);

        %E4Aのデータ数がKS2より少ないなら
        if(e4M < ksM)
            %KS2のデータ数分まで前値保持する

            %最終行のデータを取得
            MatrixV= e4X(e4M,:);

            %最終行をKS2の長さ分コピー
            e4X = vertcat(e4X,MatrixV(ones(1,ksM-e4M),:));
        end

        %E4Aのヘッダ情報の項目列を削除する
        %旧タイプの場合
        if(g_CsvFormat == 0)

            %ID番号の削除
            e4Header(1,2)={''};

            %タイトルの削除
            e4Header(2,2)={''};

            %試験日時の削除
            e4Header(3,2:3)={''};

            %KS2の測定CH数の置き換え
            Header(4,2)= {(cell2mat(Header(4,2)) + cell2mat(e4Header(4,2)))};

            %測定CH数の削除
            e4Header(4,2)={''};

            %サンプリング周波数の削除
            e4Header(6,2)={''};

            %集録データ数の削除
            e4Header(7,2)={''};

            %測定時間の削除
            e4Header(8,2)={''};

        %標準タイプの場合
        else

            %ID番号の削除
            e4Header(1,2)={''};

            %タイトルの削除
            e4Header(2,2)={''};

            %試験日時の削除
            e4Header(3,2:3)={''};

            %KS2の測定CH数の置き換え
            Header(4,2)= {(cell2mat(Header(4,2)) + cell2mat(e4Header(4,2)))};     %ver1.03

            %測定CH数の削除
            e4Header(4,2)={''};

            %サンプリング周波数の削除
            e4Header(5,2)={''};

            %集録データ数の削除
            e4Header(6,2)={''};

            %測定時間の削除
            e4Header(7,2)={''};
        end

        %KS2の集録CH数の合計が1CHの場合，KS2のヘッダ情報の試験日時の3列目をE4A試験日時の2列目にコピー
        if(ksN == 2)
            e4Header(3,2) = Header(3,3);

            Header(:,3)=[];
        end
        %E4AのヘッダとKS2のヘッダを結合
        Header = horzcat(Header,e4Header(:,2:end));

        %E4AデータとKS2データを結合
        KSX = horzcat(KSX,e4X(:,2:end));
    end

    fileName_saved = file;
    fileName_saved((strfind(fileName_saved, '.') + 1):end) = 'mat';
    disp(['file ', fileName_saved, ' saved!'])
    save(fileName_saved, 'Header', 'KSX')

%--------------------------------------------------------------------------

%% makeDispMessage - エラーメッセージの生成
%    引数
%        pos       ... エラー時の番号
%    戻り値
%        strSndBuf ... 対象の文字列
function strSndBuf = makeDispMessage(pos,tblInfo)

    if strcmp(tblInfo.Lang,tblInfo.CmpLang)
        switch pos
            case 1
                strMsgBuf = tblInfo.Error{1};
                strMsgBuf = sprintf('%s:ファイル名を拡張子付で入力して下さい。', strMsgBuf);
                strMsgBuf = sprintf('%s\n例 : X    = ksread3(''filename'');', strMsgBuf);
                strMsgBuf = sprintf('%s\nor  [X,H] = ksread3(''filename'');', strMsgBuf);
                strMsgBuf = sprintf('%s\nor   X    = ksread3(''filename'',OptNo);', strMsgBuf);
                strMsgBuf = sprintf('%s\nor  [X,H] = ksread3(''filename'',OptNo);\n', strMsgBuf);
                strMsgBuf = sprintf('%s\nX                ... 抽出したデータ配列', strMsgBuf);
                strMsgBuf = sprintf('%s\nH                ... CH情報\n', strMsgBuf);
                strMsgBuf = sprintf('%s\nfilename         ... 対象データファイル(拡張子も含む)', strMsgBuf);
                strMsgBuf = sprintf('%s\nOptNo(option)    ... データブロック番号\n', strMsgBuf);
                strMsgBuf = sprintf('%s                     またはE4Aファイルの同時読み込み(-1を指定し，''filename''がKS2ファイルの場合)', strMsgBuf);
            case 2
                strMsgBuf = tblInfo.Error{2};
                strMsgBuf = sprintf('%s:指定されたオプションの数が不正です。', strMsgBuf);
            case 3
                strMsgBuf = tblInfo.Error{3};
                strMsgBuf = sprintf('%s:拡張子が指定されていません。:(%s)', strMsgBuf,tblInfo.err);
            case 11
                strMsgBuf = tblInfo.Error{11};
                strMsgBuf = sprintf('%s:指定されたファイルが存在しないか、ファイル名が間違っています。', strMsgBuf);
            case 12
                strMsgBuf = tblInfo.Error{12};
                strMsgBuf = sprintf('%s:指定されたブロック番号は不正です。', strMsgBuf);
            case 13
                strMsgBuf = tblInfo.Error{13};
                strMsgBuf = sprintf('%s:指定されたブロック番号が数値ではありません。', strMsgBuf);
                strMsgBuf = sprintf('%s\nブロック番号には数値を指定してください。', strMsgBuf);
            case 14
                strMsgBuf = tblInfo.Error{14};
                strMsgBuf = sprintf('%s:指定されたファイルは%sファイルではありません。', strMsgBuf, tblInfo.CmpExt);
            case 15
                strMsgBuf = tblInfo.Error{15};
                strMsgBuf = sprintf('%s:指定されたファイルに対応したE4Aファイルが存在しません。', strMsgBuf);
            case 16
                strMsgBuf = tblInfo.Error{16};
                strMsgBuf = sprintf('%s:指定されたE4AファイルとKS2ファイルの集録条件が異なります。', strMsgBuf);
                strMsgBuf = sprintf('%s\nE4AファイルとKS2ファイルを確認してください。', strMsgBuf);
            case 17
                strMsgBuf = tblInfo.Error{17};
                strMsgBuf = sprintf('%s:KS2ファイルかE4Aファイルを指定してください。', strMsgBuf);
            case 21
                strMsgBuf = tblInfo.Error{21};
                strMsgBuf = sprintf('%s:\n', strMsgBuf);
                strMsgBuf = sprintf('%s対象ファイルをオープンするためには、現在メモリが足りません。', strMsgBuf);
                strMsgBuf = sprintf('%s\nHELP MEMORYとタイプしてオプションを確認してください。', strMsgBuf);
            case 22
                strMsgBuf = sprintf('%s:\n%s\n%s\n', tblInfo.Error{22}, tblInfo.err.message, tblInfo.err.identifier);
            case 31
                strMsgBuf = sprintf('データ集録数          = %d',tblInfo.LngHeight);
                disp(strMsgBuf);
                strMsgBuf = '';
            case 32
                strMsgBuf = sprintf('Please wait ... データ変換中(%sファイル)',tblInfo.ext);
            case 100
                strMsgBuf = sprintf('ファイルID            = %s',tblInfo.machine);
                strMsgBuf = sprintf('%s\nバージョン            = %s', strMsgBuf,tblInfo.version);
                strMsgBuf = sprintf('%s\n最大データブロック数   = %d', strMsgBuf,tblInfo.BlockNo);
                strMsgBuf = sprintf('%s\n指定データブロック番号 = %d', strMsgBuf,tblInfo.dataBlockNo);
                strMsgBuf = sprintf('%s\n集録CH数              = %d', strMsgBuf,tblInfo.chAll);
                strMsgBuf = sprintf('%s\n個別集録CH数          = %d', strMsgBuf,tblInfo.ch);
                strMsgBuf = sprintf('%s\nサンプリング周波数(%s) = %d', strMsgBuf,tblInfo.HzChar,tblInfo.Hz);
                disp(strMsgBuf);
                strMsgBuf = '';
            otherwise
        end
    else
        switch pos
            case 1
                strMsgBuf = tblInfo.Error{1};
                strMsgBuf = sprintf('%s:Please insert a file name with extensions.',strMsgBuf);
                strMsgBuf = sprintf('%s\nexp: X    = ksread3(''filename'');', strMsgBuf);
                strMsgBuf = sprintf('%s\nor   X    = ksread3(''filename'',OptNo);', strMsgBuf);
                strMsgBuf = sprintf('%s\nor  [X,H] = ksread3(''filename'',OptNo);\n', strMsgBuf);
                strMsgBuf = sprintf('%s\nX                ... extracted data array', strMsgBuf);
                strMsgBuf = sprintf('%s\nH                ... CH\n', strMsgBuf);
                strMsgBuf = sprintf('%s\nfilename         ... data file(include extension)', strMsgBuf);
                strMsgBuf = sprintf('%s\nOptNo(option)    ... Data block No. \n', strMsgBuf);
                strMsgBuf = sprintf('%s　　　　　　　　　　　 Or both KS2 and E4A file Read-mode(If specified value is -1 and specified ''filename'' is KS2 file)\n', strMsgBuf);
            case 2
                strMsgBuf = tblInfo.Error{2};
                strMsgBuf = sprintf('%s:Intended the number of option is incorrect.', strMsgBuf);
            case 3
                strMsgBuf = tblInfo.Error{3};
                strMsgBuf = sprintf('%s:The file which is intended is no extension.(%s)', strMsgBuf,tblInfo.err);
            case 11
                strMsgBuf = tblInfo.Error{11};
                strMsgBuf = sprintf('%s:The file which is intended is nonexistent of filen name is incorrect.', strMsgBuf);
            case 12
                strMsgBuf = tblInfo.Error{12};
                strMsgBuf = sprintf('%s:Intended block No. is incorrect.', strMsgBuf);
            case 13
                strMsgBuf = tblInfo.Error{13};
                strMsgBuf = sprintf('%s:Intended block No. is not numeric.', strMsgBuf);
                strMsgBuf = sprintf('%s\nPlease intend numeric on the block No.', strMsgBuf);
            case 14
                strMsgBuf = tblInfo.Error{14};
                strMsgBuf = sprintf('%s:Specified file is not %s file.', strMsgBuf, tblInfo.CmpExt);
            case 15
                strMsgBuf = tblInfo.Error{15};
                strMsgBuf = sprintf('%s:Specified file is not existent.', strMsgBuf);
            case 16
                strMsgBuf = tblInfo.Error{16};
                strMsgBuf = sprintf('%s:Measurement parameter E4A file and KS2 file is diffrent.', strMsgBuf);
                strMsgBuf = sprintf('%s\nPlease check E4A file and KS2 file.', strMsgBuf);
            case 17
                strMsgBuf = tblInfo.Error{17};
                strMsgBuf = sprintf('%s:Specified KS2 file of E4A file.', strMsgBuf);
            case 21
                strMsgBuf = sprintf('%s:%s\n%s\n', tblInfo.Error{21}, tblInfo.err.message, tblInfo.err.identifier);
                strMsgBuf = sprintf('%s\nThere is insufficient memory spece.', strMsgBuf);
                strMsgBuf = sprintf('%s\nPlease confirm the option by typing HELP MEMORY', strMsgBuf);
            case 22
                strMsgBuf = sprintf('%s:\n%s\n%s\n', tblInfo.Error{22}, tblInfo.err.message, tblInfo.err.identifier);
            case 31
                strMsgBuf = sprintf('Scanning Data Length / CH        = %d',tblInfo.LngHeight);
                disp(strMsgBuf);
                strMsgBuf = '';
            case 32
                strMsgBuf = sprintf('Please wait ... translate data(%s file)',tblInfo.ext);
            case 100
                strMsgBuf = sprintf('FileID                           = %s',tblInfo.machine);
                strMsgBuf = sprintf('%s\nVersion                          = %s', strMsgBuf, tblInfo.version);
                strMsgBuf = sprintf('%s\nThe number of max. data block    = %d', strMsgBuf, tblInfo.BlockNo);
                strMsgBuf = sprintf('%s\nA number of max. data block      = %d', strMsgBuf, tblInfo.dataBlockNo);
                strMsgBuf = sprintf('%s\nThe number of max. recording CH. = %d', strMsgBuf, tblInfo.chAll);
                strMsgBuf = sprintf('%s\nThe number of recording CH.      = %d', strMsgBuf, tblInfo.ch);
                strMsgBuf = sprintf('%s\nRecording frequency(%s)          = %d', strMsgBuf, tblInfo.HzChar,tblInfo.Hz);
                disp(strMsgBuf);
                strMsgBuf = '';
            otherwise
        end
    end
    strSndBuf = strMsgBuf;

%--------------------------------------------------------------------------
%% テキスト部の情報取得
%    引数
%        fid     ... ファイルポインタオブジェクト
%        tblInfo ... 構造体変数
%    戻り値
%        info    ... 情報を追加した構造体変数

function info = getInfo(fid,tblInfo)

    delm = ' ';
    i = 1;
    while 1
        line = fgetl(fid);
        if (i <= 2)
          tbls = split_str(line(2:(length(line)-1)),delm);
          if i == 1
              tblInfo.machine = tbls{1}; % 名前
          else
              tblInfo.version = tbls{1}; % バージョン
              if strcmp(tblInfo.version,'01.00.00')
                  i = i + 1;
              end
          end
        elseif (i > 2) && (i <= 16)
            if i == 7
                tbls = split_str(line(2:(length(line)-1)),delm);
                strRcvBuf = tbls{1};
            else
                strRcvBuf = line;
            end
            if i == 4
                tblInfo.chAll = str2double(strRcvBuf);
            elseif i == 5
                tblInfo.ch    = str2double(strRcvBuf);
            elseif i == 6
                token = str2double(strRcvBuf);
                if token == 0
                    token = 1;
                end
                tblInfo.Hz = token;
            elseif i == 7
                tblInfo.HzChar = strRcvBuf;
            elseif i == 10
                tblInfo.BlockNo = str2double(strRcvBuf);
            elseif i == 11                                       % KS1->0,KS2->1
                check = strcmp(tblInfo.ext,tblInfo.CmpExt);
                if check == 0
                    tblInfo.CAN = 0;
                else
                    token = strRcvBuf(2:length(strRcvBuf));
                    if isempty(token)
                        token = 0;
                    else
                        token = str2double(token(1:(length(token)-1)));
                        if length(token) < 1
                            token = 0;            % tokenが空の場合
                        end
                    end
                    tblInfo.CAN = token;
                end
            elseif i == 13
                tblInfo.variableHeader = str2double(strRcvBuf);
            elseif i == 14
                tblInfo.dataHeader     = str2double(strRcvBuf);
            end
        else
            break;
        end
        i = i + 1;
    end
    info = tblInfo;



%--------------------------------------------------------------------------
%% DataRead - データを読み込む手順を行う
%    引数
%        f           ... ファイルポインタオブジェクト
%        tblInfo     ... ヘッダ各種情報を格納した構造体変数
%    戻り値
%        strSndBuf ... 抽出した集録データ
%        tblHeader ... CH情報

function [strSndBuf, tblHeader, CanChNum] = DataRead12(f,tblInfo)
    global g_NtbFlag;         %測定器がNTBかを示すフラグ
    global g_CsvFormat;       %ヘッダ情報のフォーマットの旧式・標準を切り替えます      0：旧タイプ  1：標準タイプ
    global g_IndexType;       %データのインデックスを切り替えます                     0：時間      1：番号

% initalized variable
    lngSeek = tblInfo.HeadSeek;                 % テキスト部バイト数
    delta   = 0;                                % データの読み飛ばし量
    tblCoeff  = zeros(1,tblInfo.ch,'double');   % 工学値変換係数A edit at 2012/09/28   single→doubleに変更  動作はどちらでも正常
    tblOffset = zeros(1,tblInfo.ch,'double');   % 工学値変換係数B edit at 2012/09/28   single→doubleに変更  動作はどちらでも正常
    tblName = {};                               % チャネル名
    tblNo = {};                                 % チャネルNo
    tblUnit = {};                               % 単位文字列
    tblrange = {};                              % レンジ
    tblCoeff_disp = {};                         % 校正係数
    tblOffset_disp = {};                        % オフセット
    tblLowPass = {};                            % ローパスフィルタ
    tblHighPass = {};                           % ハイパスフィルタ
    tblDigiFilter = {};                         % ハイパスフィルタ
    tblfileDate ={};                            % 試験日時
    tblfileData_num = {};                       % データ/ch
    tblChMode = {};                             % CHモード
    tblGaugeFactor = {};                        % ゲージ率
    tblZeroMode = {};                           % ZERO値のモード
    tblZeroNum = {};                            % ZERO値
    blkLMT      = tblInfo.BlockNo;              % 最大ブロック数
    dataBlockNo = tblInfo.dataBlockNo;          % 引数で指定したブロック番号
    flgDebug  = 0;                              % 情報表示を操作するフラグ(0:非表示,1:表示)
    g_NtbFlag = 0;                              % 測定器がNTBかを示すフラグ
    tblInfo.checkArray = [];                    % チェック用配列(depend printInfoAbove)

    cell_data = cell(1,tblInfo.chAll+1);        % ディジタルCHを含む全チャンネル
    cell_data(:,:)={''};                        % 空データで初期化する

    %可変長ヘッダ部情報
    [parent,child] = checkFlag(f,lngSeek,delta);
    while parent < 3
        [smlSeek,strCharBuf] = makeSeek(f,parent,child);
        [delta,strRcvBuf,flgCoeff,tblInfo] = printInfoAbove(f,tblInfo, parent,child,...
                                                          smlSeek,strCharBuf, tblCoeff,tblOffset,...
                                                          delta,flgDebug,cell_data);
        [parent,child] = checkFlag(f,lngSeek,delta);
        switch flgCoeff
            case 1,     tblCoeff = strRcvBuf;           %   工学値変換係数A
            case 2,     tblOffset = strRcvBuf;          %   工学値変換係数B
            case 3,     tblNo = strRcvBuf;              %   CH番号
            case 4,     tblName = strRcvBuf;            %   CH名称
            case 5,     tblUnit = strRcvBuf;            %   単位
            case 6,     tblrange = strRcvBuf;           %   レンジ
            case 7,     tblCoeff_disp = strRcvBuf;      %   校正係数
            case 8,     tblOffset_disp = strRcvBuf;     %   オフセット
            case 9,     tblLowPass = strRcvBuf;         %   ローパスフィルタ
            case 10,    tblHighPass = strRcvBuf;        %   ハイパスフィルタ
            case 11,    tblDigiFilter = strRcvBuf;      %   デジタルフィルタ
            case 12,    tblChMode = strRcvBuf;          %   CHモード
            case 13,    tblGaugeFactor = strRcvBuf;     %   ゲージ率
            case 14,    tblZeroMode = strRcvBuf;        %   ZERO値のモード
        end
    end

    %データ部情報
    for i = 1:blkLMT
        [parent,child] = checkFlag(f,lngSeek,delta);
        flags = parent;
        while flags <= parent
            switch i
             case dataBlockNo
              flgDebug = 1;
            end
            [smlSeek,strCharBuf] = makeSeek(f,parent,child);
            [delta,strRcvBuf,flgCoeff,tblInfo] = printInfoAbove(f,tblInfo, parent,child,...
                                                              smlSeek,strCharBuf, tblCoeff,tblOffset,...
                                                              delta,flgDebug,cell_data);
            [parent,child] = checkFlag(f,lngSeek,delta);

            switch flgCoeff
                case 9                          %   試験日時
                    tblfileDate = strRcvBuf;
                case 10                         %   データ数/ch
                    tblfileData_num = strRcvBuf;
            end

            if flags < parent
                flags = parent;
            elseif parent > 18
                break;
            end
            switch flgCoeff
             case 3, strSndBuf = strRcvBuf;
             case 111
                 strSndBuf = 111;
                 tblHeader = tblInfo;
                 CanChNum = tblInfo.CanChNum;
                 return
             case 999
                 strSndBuf = 999;
                 tblHeader = tblInfo;
                 CanChNum = tblInfo.CanChNum;
                 return
            end
        end
        switch i
         case dataBlockNo, break
        end
    end

%チャンネル名称，レンジ，単位はKS2ファイルに必須な項目では無いため，データが見つからなかった場合の処理

    if(isempty(tblName)==1)
        tblName = cell(1,tblInfo.chAll+tblInfo.CanChNum+1);
        tblName(:,:)={''};
        %tblName(1,1)={'[CH名称]'};
        tblName(1,1)={'[CH Name]'};
    end
    if(isempty(tblrange)==1)
        tblrange = cell(1,tblInfo.chAll+tblInfo.CanChNum+1);
        tblrange(:,:)={0};
        %tblrange(1,1)={'[レンジ]'};
        tblrange(1,1)={'[Range]'};
    end
    if(isempty(tblUnit)==1)
        tblUnit = cell(1,tblInfo.chAll+tblInfo.CanChNum+1);
        tblUnit(:,:)={''};
        %tblUnit(1,1)={'[単位]'};
        tblUnit(1,1)={'[Unit]'};
    end
    if(isempty(tblLowPass)==1)
        tblLowPass = cell(1,tblInfo.chAll+tblInfo.CanChNum+1);
        tblLowPass(:,:)={'**'};
        %tblLowPass(1,1)={'[ローパスフィルタ]'};
        tblLowPass(1,1)={'[Low Pass Filter]'};
        for i = tblInfo.ch+1:tblInfo.chAll+tblInfo.CanChNum-1
            tblLowPass(i+2)={''};
        end
    else
    end
    if(isempty(tblHighPass)==1)
        tblHighPass = cell(1,tblInfo.chAll+tblInfo.CanChNum+1);
        tblHighPass(:,:)={'**'};
        %tblHighPass(1,1)={'[ハイパスフィルタ]'};
        tblHighPass(1,1)={'[High Pass Filter]'};
        for i = tblInfo.ch+1:tblInfo.chAll+tblInfo.CanChNum-1
            tblHighPass(i+2)={''};
        end
    end
    if(isempty(tblDigiFilter)==1)
        tblDigiFilter = cell(1,tblInfo.chAll+tblInfo.CanChNum+1);
        tblDigiFilter(:,:)={'***'};
        %tblDigiFilter(1,1)={'[デジタルフィルタ]'};
        tblDigiFilter(1,1)={'[Digital Filter]'};
        for i = tblInfo.ch++1:tblInfo.chAll+tblInfo.CanChNum-1
            tblDigiFilter(i+2)={''};
        end
    end

    %ZERO値の項目が無かった場合
    if(isempty(tblZeroMode)==1)
        g_NtbFlag = 0;
    else
        g_NtbFlag = 1;
        %tblZeroNum(1,1) = {'[ZERO値]'};
        tblZeroNum(1,1) = {'[ZERO Value]'};
        tblZeroMode(1,1) = {'[ZERO]'};
        %ZERO値とZEROのモードの項目を分解する
        for i = 1:tblInfo.chAll
            TempStr = split_str(cell2mat(tblZeroMode(1,i+1)),',');
            tblZeroNum(1,i+1) = TempStr(1);
            tblZeroMode(1,i+1) = TempStr(2);
        end
    end
%アナログCHが無かった場合の処理
    if (tblInfo.ch == 0)
        %CH番号セルの初期化
        if g_CsvFormat == 0
            tblNo(1) = {'[CH No]'};
        else
            if g_IndexType == 0
                tblNo(1) = {'[Time(sec)]'};
            else
                tblNo(1) = {'[No.]'};
            end
        end

        %校正係数セルの初期化
        %tblCoeff_disp(1)={'[校正係数]'};
        tblCoeff_disp(1)={'[Calibration Coeff.]'};

        %オフセットセルの初期化
        %tblOffset_disp(1)={'[オフセット]'};
        tblOffset_disp(1)={'[Offset]'};

        tblInfo.CanChStNo = 1;
    end

%CANデータがある場合の処理
    if (tblInfo.CAN ~= 0)
        CanChNum = tblInfo.CanChNum;
        for k = 1:CanChNum
            %CAN-CH番号の設定
            tblNo(k+tblInfo.ch+1) = {strcat('CH-',num2str(tblInfo.CanChStNo+(k-1)))};

            %CAN-CH名称の設定
            if(isempty(nonzeros(tblInfo.CanCh(k).ChName))==0)
                tblName(k+tblInfo.ch+1) = {native2unicode(nonzeros(tblInfo.CanCh(k).ChName)')};
            else
                tblName(k+tblInfo.ch+1) = {''};
            end

            %CAN-CH校正係数の設定(floatかdoubleかの判定追加必要)
            tblCoeff_disp(k+tblInfo.ch+1) = {tblInfo.CanCh(k).Coeffs};

            %CAN-CHオフセットの設定(floatかdoubleかの判定追加必要)
            tblOffset_disp(k+tblInfo.ch+1) = {tblInfo.CanCh(k).Offset};

            %単位文字列の設定
            if(isempty(nonzeros(tblInfo.CanCh(k).UnitStr))==0)
                tblUnit(k+tblInfo.ch+1) = {native2unicode(nonzeros(tblInfo.CanCh(k).UnitStr)')};
            end
        end
    end

%配列の初期化
    tblInfo.DigiChNum = (tblInfo.chAll-tblInfo.ch);
    tblInfo.MeasChNum = tblInfo.chAll + tblInfo.CanChNum;

    %試験日時の初期化
    %集録CH数が2より大きいなら配列の4番目から配列の初期化を行う
    if(tblInfo.MeasChNum > 2)
        tblfileDate(4:tblInfo.MeasChNum+1) = {''};
    end

    %集録データ数の初期化
    %集録CH数が2より大きいなら配列の4番目から配列の初期化を行う
    if( (tblInfo.MeasChNum) > 1)
        tblfileData_num(3:tblInfo.MeasChNum+1) = {''};
    else
        %配列の3番目を初期化
        tblfileData_num(:,3) = {''};
    end

    %CH名称，校正係数，オフセット，単位の初期化
    %DIの集録があった場合そのCH数分初期化を行う
    if( (tblInfo.ch + tblInfo.CanChNum) == 0)
        tblName(2:3) = {''};
        tblCoeff_disp(2:3) = {''};
        tblOffset_disp(2:3) = {''};
        tblUnit(2:3) = {''};
    elseif((tblInfo.ch + tblInfo.CanChNum) == 1)
        if(tblInfo.DigiChNum == 1)
            %配列の3番目を初期化
            tblName(:,3) = {''};
            tblCoeff_disp(:,3) = {''};
            tblOffset_disp(:,3) = {''};
            tblUnit(:,3) = {''};
        elseif(tblInfo.DigiChNum == 2)
            %配列の3,4番目を初期化
            tblName(3:4) = {''};
            tblCoeff_disp(3:4) = {''};
            tblOffset_disp(3:4) = {''};
            tblUnit(3:4) = {''};
        else
            %配列の3番目を初期化
            tblName(:,3) = {''};
            tblCoeff_disp(:,3) = {''};
            tblOffset_disp(:,3) = {''};
            tblUnit(:,3) = {''};
        end
    else
        if(tblInfo.DigiChNum ~= 0)
            tblName((tblInfo.ch + tblInfo.CanChNum)+2:tblInfo.MeasChNum+1) = {''};
            tblCoeff_disp((tblInfo.ch + tblInfo.CanChNum)+2:tblInfo.MeasChNum+1) = {''};
            tblOffset_disp((tblInfo.ch + tblInfo.CanChNum)+2:tblInfo.MeasChNum+1) = {''};
            tblUnit((tblInfo.ch + tblInfo.CanChNum)+2:tblInfo.MeasChNum+1) = {''};
        end
    end

    %CH Noの初期化
    %DIの集録があった場合そのCH数分初期化を行う
    if( (tblInfo.MeasChNum) == 1)
        tblNo(3) = {''};
    end

    if(tblInfo.DigiChNum == 1)
        tblNo((tblInfo.ch + tblInfo.CanChNum)+2) = {'DI-1'};
    elseif(tblInfo.DigiChNum == 2)
        tblNo((tblInfo.ch + tblInfo.CanChNum)+2) = {'DI-1'};
        tblNo((tblInfo.ch + tblInfo.CanChNum)+3) = {'DI-2'};
    end

    %レンジ，ローパス，ハイパス，デジタルの初期化
    %アナログのCH数が0or1なら配列の3番目まで初期化
    if(tblInfo.ch == 0)
        tblrange(2:3) = {''};
        tblLowPass(2:3)={''};
        tblHighPass(2:3)={''};
        tblDigiFilter(2:3)={''};
    elseif(tblInfo.ch == 1)
        tblrange(3) = {''};
        tblLowPass(3)={''};
        tblHighPass(3)={''};
        tblDigiFilter(3)={''};
    end
    if( (tblInfo.DigiChNum + tblInfo.CanChNum) ~= 0)
        tblrange(tblInfo.ch+2:tblInfo.MeasChNum+1) = {''};
        tblLowPass(tblInfo.ch+2:tblInfo.MeasChNum+1)={''};
        tblHighPass(tblInfo.ch+2:tblInfo.MeasChNum+1)={''};
        tblDigiFilter(tblInfo.ch+2:tblInfo.MeasChNum+1)={''};
    end



    %NTBの場合，CHモード，ゲージ率，ZERO,ZERO値の項目を追加する
    if g_NtbFlag == 1
        if(tblInfo.chAll == 1)
            tblChMode(:,3)      = {''};
            tblGaugeFactor(:,3) = {''};
            tblZeroMode(:,3)    = {''};
            tblZeroNum(:,3)     = {''};
        end
        tblHeader = [tblName;tblNo;tblChMode;tblrange;tblCoeff_disp;tblOffset_disp;tblGaugeFactor;tblZeroMode;tblZeroNum;tblUnit;tblfileDate;tblfileData_num];
    else
        tblHeader = [tblName;tblNo;tblrange;tblHighPass;tblLowPass;tblDigiFilter;tblCoeff_disp;tblOffset_disp;tblUnit;tblfileDate;tblfileData_num];
    end

    return
%--------------------------------------------------------------------------
%% checkFlag - 大分類,小分類フラグを読み出す
%    引数
%        f         ... ファイルポインタオブジェクト
%        lngSeek   ... ヘッダサイズ
%        delta     ... ヘッダ以降の読み飛ばし量
%    戻り値
%        parent    ... 大分類フラグ
%        child     ... 小分類フラグ
function [parent,child] = checkFlag(f,lngSeek,delta)

    fseek(f,lngSeek + delta,'bof');
    if feof(f) == 0                  % 終端処理
        parent = fread(f,1,'uchar');
        child  = fread(f,1,'uchar');
    else
        parent = 0;
        child  = 0;
    end


%--------------------------------------------------------------------------
%% makeSeek - データ読み込みバイト数、およびデータ型を読み取る。
%    引数
%        f          ... ファイルポインタオブジェクト
%        parent     ... 大分類フラグ
%        child      ... 小分類フラグ
%    戻り値
%        smlSeek    ... データ読み込みバイト数
%        strCharBuf ... データ型
function [smlSeek,strCharBuf] = makeSeek(f,parent,child)

    flgSeek = checkflgSeek(parent,child);
    if flgSeek == 4
        smlSeek = fread(f,1,'uint32') - 2;
    elseif flgSeek == 8
        smlSeek = fread(f,1,'uint64') - 2;
    else
        smlSeek = fread(f,1,'uint16') - 2;
    end

    if (child == 61)
        strCharBuf = checkCharacter(fread(f,1,'int16'));
    elseif (child == 62)
        strCharBuf = checkCharacter(fread(f,1,'int16'));
    elseif (child == 63)
        strCharBuf = checkCharacter(fread(f,1,'int32'));
    elseif (child == 70)
        strCharBuf = checkCharacter(fread(f,1,'int16'));
    else
        fseek(f,1,'cof');
        pos = fread(f,1,'uchar');
        strCharBuf = checkCharacter(pos);
    end


%--------------------------------------------------------------------------
%% checkflgSeek - 読込みバイト量を算出
%    引数
%        flgParent     ... 大分類フラグ
%        flgChild      ... 小分類フラグ
%    戻り値
%        flgSeek       ... 対応したバイト数
%
function flgSeek = checkflgSeek(flgParent,flgChild)
    global g_Ks2VerNum;

    if flgParent == 1
        if flgChild == 61               % CAN ID情報
            %KS2のVerが5以上ならボディバイト数は4
            if g_Ks2VerNum >= 5
                flgSeek = 4;
            else
                flgSeek = 2;
            end
        elseif flgChild == 62           % CAN CH条件(KS2)
            flgSeek = 4;
        elseif flgChild == 63           % CAN通信条件
            %KS2のVerが5以上ならボディバイト数は4
            if g_Ks2VerNum >= 5
                flgSeek = 4;
            else
                flgSeek = 2;
            end
        elseif flgChild == 70           % CAN CH条件(KS2)
            flgSeek = 4;
        else
            flgSeek = 2;
        end
    elseif flgParent == 16
        if flgChild == 34           % MAX/MINデータ
            %KS2のVerが5以上ならボディバイト数は4
            if g_Ks2VerNum >= 5
                flgSeek = 4;
            else
                flgSeek = 2;
            end
        elseif flgChild == 35       % MAX/MIN前後400データ(KS2)
                flgSeek = 4;
        elseif flgChild == 36       % MAX/MIN5データのMAX/MIN発生ポイント
            %KS2のVerが5以上ならボディバイト数は4
            if g_Ks2VerNum >= 5
                flgSeek = 4;
            else
                flgSeek = 2;
            end
        else
            flgSeek = 2;
        end
    elseif flgParent == 17
        if flgChild == 1            % データ部(ks1)
            flgSeek = 4;
        elseif flgChild == 2        % データ部(KS2)
            flgSeek = 8;
        end
    elseif flgParent == 18
        if flgChild == 25           % REC/PAUSE時間(KS2)
            flgSeek = 8;
        elseif flgChild == 31
            flgSeek = 2;
        elseif flgChild == 32
            flgSeek = 2;
        else
            flgSeek = 4;
        end
    else
        flgSeek = 2;
    end

%--------------------------------------------------------------------------
%% printInfoAbove - 各情報を読み取る。
%    引数
%        f          ... ファイルポインタオブジェクト
%        tblInfo    ... ヘッダ各種情報を格納した構造体変数
%        flgParent  ... 大分類フラグ
%        flgChild   ... 小分類フラグ
%        smlSeek    ... データ読み込みバイト数
%        strCharBuf ... データ型
%        tblCoeff   ... 校正係数
%        tblOffset  ... オフセット
%        delta      ... 読み飛ばし量
%        flgDebug   ... 情報表示有無を操作するフラグ(0:非表示,1:表示)
%        cell_data  ... CH情報を一時保管配列
%    戻り値
%        delta      ... 読み飛ばし量
%        strSndBuf  ... 校正係数,オフセット,実際のデータ等
%        flgCoeff   ... 校正係数,オフセット,実際のデータの振り分け
%        tblInfo    ... 変更を加えた構造体変数


function [delta,strSndBuf,flgCoeff,tblInfo] = printInfoAbove(f,tblInfo,flgParent,flgChild,smlSeek, strCharBuf,tblCoeff,tblOffset,delta,flgDebug,cell_data)
    global g_Ks2VerNum;
    global g_CsvFormat;       %ヘッダ情報のフォーマットの旧式・標準を切り替えます      0：旧タイプ  1：標準タイプ
    global g_IndexType;       %データのインデックスを切り替えます                     0：時間      1：番号
    global g_StartNumber;     %データのインデックスの開始番号を切り替えます            0：0始まり   1：1始まり

    persistent CanIdMax;        %CAN-IDの最大数
    persistent CanChMax;        %CAN-CHの最大数
    persistent DoubleMax;       %Double型最大値
    persistent DoubleMin;       %Double型最小値
    persistent FloatMax;        %Float型最大値
    persistent FloatMin;        %Float型最小値
    persistent CanIdEndian;     %CAN-IDエンディアン
    persistent CanIdDataLen;    %CAN-IDデータ長
    persistent CanIdChNum;      %CAN-IDのCH数
    persistent CanChBitShiftR;  %CAN-CH分解用右側ビットシフト
    persistent CanChStBit;      %CAN-CHスタートビット
    persistent CanChProcType;   %CAN-CHデータ型
    persistent CanChDataType;   %CAN-CHデータ型
    persistent CanChBitLen;     %CAN-CHビット長
    persistent CanChBitMask;    %CAN-CHビットマスク
    persistent CanChSignedMask; %CAN-CHSigned型変換マスク
    persistent CanChCoeffs;     %CAN-CH校正係数
    persistent CanChOffset;     %CAN-CHオフセット
    persistent CanChData;       %CAN-CHデータ(uint64)
    persistent SignedCanChData; %CAN-CHデータ(int64)
    persistent DoubleCanChData; %CAN-CHデータ(double)

%以下，一回目の呼び出し時に行列の初期化を行う
    %CAN-ID数の最大値は5120
    if (isempty(CanIdMax))
        CanIdMax = 5120;
    end

    %CAN-CH数の最大値は10240
    if (isempty(CanChMax))
        CanChMax = 10240;
    end

    %Double型最大値の設定
    if (isempty(DoubleMax))
        DoubleMax = realmax('double');
    end

    %Double型最小値の設定
    if (isempty(DoubleMin))
        DoubleMin = realmin('double');
    end

    %Float型最大値の設定
    if (isempty(FloatMax))
        FloatMax = realmax('single');
    end

    %Float型最小値の設定
    if (isempty(FloatMin))
        FloatMin = realmin('single');
    end

    if (isempty(CanIdEndian))
        CanIdEndian = zeros(1,5120,'uint32');
    end
    if (isempty(CanIdDataLen))
        CanIdDataLen = zeros(1,5120,'int32');
    end
    if (isempty(CanIdChNum))
        CanIdChNum = zeros(1,5120,'uint32');
    end
    if (isempty(CanChBitShiftR))
        CanChBitShiftR = zeros(10240,1,'int32');
    end
    if (isempty(CanChStBit))
        CanChStBit = zeros(1,10240,'uint32');
    end
    if (isempty(CanChDataType))
        CanChDataType = zeros(1,10240,'uint32');
    end
    if (isempty(CanChProcType))
        CanChProcType = zeros(1,10240,'uint32');
    end
    if (isempty(CanChBitLen))
        CanChBitLen = zeros(10240,1,'uint32');
    end
    if (isempty(CanChBitMask))
        CanChBitMask = zeros(10240,1,'uint64');
    end
    if (isempty(CanChSignedMask))
        CanChSignedMask = zeros(1,10240,'uint64');
    end
    if (isempty(CanChCoeffs))
        CanChCoeffs = zeros(1,10240,'double');
    end
    if (isempty(CanChOffset))
        CanChOffset = zeros(1,10240,'double');
    end
    if (isempty(CanChData))
        CanChData = zeros(64*32,1,'uint64');
    end
    if (isempty(SignedCanChData))
        SignedCanChData = zeros(64*32,1,'int64');
    end
    if (isempty(DoubleCanChData))
        DoubleCanChData = zeros(64*32,1,'double');
    end

    strTmpBuf = [];
    flgCoeff  = 0;
    flgDelta  = 2;

    if flgParent == 1   % 可変長ヘッダ部全体情報
        %項目名
        if flgChild == 46
            tblInfo.CoefDFlag = 0;

            if g_Ks2VerNum <= 3
                StrBufItem = zeros(1,10,'uint8');

                %15項目目までポインタを移動
                fseek(f,252,'cof');

                %先頭の10文字を読み込み
                for k = 1:10
                    StrBufItem(k) = fread(f,1,'uint8');
                end

                %文字列へ変換
                StrBuf = char(StrBufItem);

                %文字列がCAN_DOUBLEなら校正係数とオフセットはDouble型
                tblInfo.CoefDFlag = strcmp(StrBuf,'CAN_DOUBLE');
            end

        %CAN-ID情報
        elseif flgChild == 61
            tblInfo.CanChNum = 0;

            if g_Ks2VerNum >= 5
                %KS2のVerが5以上ならボディバイト数は4
                flgDelta = 4;
            else
                flgDelta = 2;
            end

            if(isnan(tblInfo.CAN) == 0)
                %CAN-ID数分読み込む
                for k = 1:tblInfo.CAN

                    %ID番号
                    tblInfo.CanId(k).IdNo = fread(f,1,'int16');

                    %1ID辺りのCH数
                    tblInfo.CanId(k).ChNum = fread(f,1,'int16');

                    %フォーマット(0：標準  1：拡張)
                    tblInfo.CanId(k).Format = fread(f,1,'int16');

                    %フレームID
                    tblInfo.CanId(k).FrameIdNo = fread(f,1,'int32');

                    %ID長
                    tblInfo.CanId(k).IdSize = fread(f,1,'int16');

                    %エンディアン(0：Little  1：Big)
                    tblInfo.CanId(k).Endian = fread(f,1,'int16');
                    fseek(f,40,'cof');

                    %CAN-CH数の設定
                    CanIdChNum(k) = tblInfo.CanId(k).ChNum;

                    %CAN-ID長の設定
                    CanIdDataLen(k) = tblInfo.CanId(k).IdSize;

                    %エンディアンがLittleなら1，Bigなら2を設定
                    if(tblInfo.CanId(k).Endian == 0)
                       CanIdEndian(k) = 1;
                    else
                       CanIdEndian(k) = 2;
                    end

                    %CAN-CH数の更新
                    tblInfo.CanChNum = tblInfo.CanChNum + tblInfo.CanId(k).ChNum;
                end
            end

        %CAN-CH条件
        elseif flgChild == 62
            flgDelta = 4;

            %CAN-CH数分の読み込み
            for k = 1:tblInfo.CanChNum

                %スタートビットの読み込み
                CanChStBit(k) = fread(f,1,'int16=>uint32');

                %ビット長の読み込み
                CanChBitLen(k) = fread(f,1,'int16=>uint32');

                %データ型の読み込み
                CanChDataType(k) = fread(f,1,'int16=>uint32');

                %6バイト読み飛ばす
                fseek(f,6,'cof');

                %単位文字列の読み込み
                tblInfo.CanCh(k).UnitStr = fread(f,10,'uchar');

                %CAN-DOUBLEが項目に書かれていたら校正係数とオフセットはDouble型
                if (tblInfo.CoefDFlag == 0)

                    %校正係数の読み込み Ver0102
                    tblInfo.CanCh(k).Coeffs = str2double(sprintf('%.7G', fread(f,1,'float')));

                    %オフセットの読み込み Ver0102
                    tblInfo.CanCh(k).Offset = str2double(sprintf('%.7G', fread(f,1,'float')));

                    %CH名称の読み込み
                    tblInfo.CanCh(k).ChName = fread(f,40,'uchar');

                %校正係数とオフセットのDobule型フラグがONなら
                else
                    %Float型の校正係数とオフセットは読み飛ばす
                    fseek(f,8,'cof');

                    %CH名称は20バイト
                    tblInfo.CanCh(k).ChName = fread(f,20,'uchar');

                    %予約4バイトを読み飛ばす
                    fseek(f,4,'cof');

                    %校正係数とオフセットの読み込み
                    tblInfo.CanCh(k).Coeffs = fread(f,1,'double');
                    tblInfo.CanCh(k).Offset = fread(f,1,'double');
                end

                %Signed型変換用マスク行列の初期化
                CanChSignedMask(k) = cast(hex2dec('FFFFFFFFFFFFFFFF'), 'uint64');

                %CAN-CH変換用右側へのビットシフト行列の設定
                CanChBitShiftR(k) = cast(CanChStBit(k),'int32');
                CanChBitShiftR(k) = CanChBitShiftR(k) * -1;

                %マスクビットとSignedマスクビットの設定
                for kk = 1:CanChBitLen(k)
                    CanChBitMask(k) = bitset(CanChBitMask(k), kk);
                    CanChSignedMask(k) = bitset(CanChSignedMask(k), kk, 0);
                end

                %校正係数の設定
                CanChCoeffs(k) = tblInfo.CanCh(k).Coeffs;

                %オフセットの設定
                CanChOffset(k) = tblInfo.CanCh(k).Offset;
            end

        %CAN通信条件
        elseif flgChild == 63
            if g_Ks2VerNum >= 5
                %KS2のVerが5以上ならボディバイト数は4
                flgDelta = 4;
            else
                flgDelta = 2;
            end
        %CAN-CH条件
        elseif flgChild == 70
            flgDelta = 4;

            %CAN-CH数分の読み込み
            for k = 1:tblInfo.CanChNum

                %スタートビットの読み込み
                CanChStBit(k) = fread(f,1,'int16=>uint32');

                %ビット長の読み込み
                CanChBitLen(k) = fread(f,1,'int16=>uint32');

                %データ型の読み込み
                CanChDataType(k) = fread(f,1,'int16=>uint32');

                %6バイト読み飛ばす
                fseek(f,6,'cof');

                %単位文字列の読み込み
                tblInfo.CanCh(k).UnitStr = fread(f,10,'uchar');

                %校正係数の読み込み
                tblInfo.CanCh(k).Coeffs = fread(f,1,'double');

                %オフセットの読み込み
                tblInfo.CanCh(k).Offset = fread(f,1,'double');

                %小数点桁数の読み込み
                tblInfo.CanCh(k).Digit = fread(f,1,'int16');

                %CH名称の読み込み
                tblInfo.CanCh(k).ChName = fread(f,40,'uchar');

                %Signed型変換用マスク行列の初期化
                CanChSignedMask(k) = cast(hex2dec('FFFFFFFFFFFFFFFF'), 'uint64');

                %CAN-CH変換用右側へのビットシフト行列の設定
                CanChBitShiftR(k) = cast(CanChStBit(k),'int32');
                CanChBitShiftR(k) = CanChBitShiftR(k) * -1;

                %マスクビットとSignedマスクビットの設定
                for kk = 1:CanChBitLen(k)
                    CanChBitMask(k) = bitset(CanChBitMask(k), kk);
                    CanChSignedMask(k) = bitset(CanChSignedMask(k), kk, 0);
                end

                %校正係数の設定
                CanChCoeffs(k) = tblInfo.CanCh(k).Coeffs;

                %オフセットの設定
                CanChOffset(k) = tblInfo.CanCh(k).Offset;
            end
        end

        strSndBuf = strTmpBuf;
    elseif flgParent == 2 % 可変長ヘッダ部個別情報
        ch = tblInfo.ch;
        chAll = tblInfo.chAll;
        array = zeros(1,ch,'single');

        j = 1;
        if (flgChild == 2) || (flgChild == 48)    % 有効チャネル番号
            flgCoeff = 3;
            checkArray = zeros(1,ch,'single');
            for i = 1:ch
                temp1 = fread(f,1,'int16');
                if flgChild == 2         % KS1の場合(有効CHの有無が0/1の情報だけ)
                    checkArray(i) = temp1; % チェック用の配列
                    if temp1 > 0
                        temp1 = i;
                        if g_CsvFormat == 0
                            strTmpBuf = makeChStrings(j,strTmpBuf,temp1,'[CH No],CH-',',CH-');
                        else
                            if g_IndexType == 0
                                strTmpBuf = makeChStrings(j,strTmpBuf,temp1,'[Time(sec)],CH-',',CH-');
                            else
                                strTmpBuf = makeChStrings(j,strTmpBuf,temp1,'[No.],CH-',',CH-');
                            end
                        end
                        j = j + 1;
                    end
                else       % KS2の場合
                    if g_CsvFormat == 0
                        strTmpBuf = makeChStrings(i,strTmpBuf,temp1,'[CH No],CH-',',CH-');
                    else
                        if g_IndexType == 0
                            strTmpBuf = makeChStrings(i,strTmpBuf,temp1,'[Time(sec)],CH-',',CH-');
                        else
                            strTmpBuf = makeChStrings(i,strTmpBuf,temp1,'[No.],CH-',',CH-');
                        end
                    end
                end
            end
            tblInfo.checkArray = checkArray;

            if(mod(temp1,16)==0)
                tblInfo.CanChStNo = temp1 + 1;
            else
                tblInfo.CanChStNo = (floor(temp1/16)+1)*16+1;
            end
            j = 1;
            for i=ch+1:chAll
                strTmpBuf = [strTmpBuf,',DI-',num2str(j)];
                j = j + 1;
            end
            strSndBuf = split_str(strTmpBuf,',');

%(KS2 ver01.01～03)の工学値変換係数AとBの抽出(float型)
        elseif (flgChild == 3) || (flgChild == 4)        % 工学値変換係数A,B
            for i = 1:ch
                %Ver0103 float型の読み込み処理の変更
                array(i) = str2double(sprintf('%.7G', fread(f,1,'float')));
            end
            if flgChild == 4
                flgCoeff = 2;
            else
                flgCoeff = 1;
            end
            strSndBuf = array;

%KS2 ver01.04の工学値変換係数AとBの抽出(double型)
        elseif (flgChild == 67) || (flgChild == 68)
            double_array =zeros(1,8,'double');
            for i = 1:ch
                double_array(i) = fread(f,1,'double');
            end
            if flgChild == 68
                flgCoeff = 2;
            else
                flgCoeff = 1;
            end
            strSndBuf = double_array;
            clear double_array

%単位文字列の抽出
        elseif flgChild == 5                            %単位
            int8_array =zeros(1,10,'uint32');
            flgCoeff = 5;
            for i = 1:ch
                for ii = 1:10
                    int8_array(ii) = fread(f,1,'uchar');
                end

                cell_data(i+1)={''};
                if(isempty(nonzeros(int8_array))==0)
                    cell_data(i+1) = {native2unicode(nonzeros(int8_array)')};
                end
            end
            %cell_data(1)={'[単位]'};
            cell_data(1)={'[Unit]'};
            strSndBuf = cell_data;
            clear int8_array

%校正係数，オフセットの抽出(ver01.01～03)
        elseif (flgChild == 8) || (flgChild ==12)            %校正係数，オフセット
            for i = 1:ch
                %Ver0103 float型の読み込み処理の変更
                cell_data(1,1+i) = {str2double(sprintf('%.7G', fread(f,1,'float')))};
            end
            if flgChild == 8
                flgCoeff = 7;
                %cell_data(1)={'[校正係数]'};
                cell_data(1)={'[Calibration Coeff.]'};
            else
                flgCoeff = 8;
                %cell_data(1)={'[オフセット]'};
                cell_data(1)={'[Offset]'};
            end
            strSndBuf = cell_data;

%校正係数，オフセットの抽出(ver01.04以降)
        elseif (flgChild == 69) || (flgChild ==70)
            for i = 1:ch
                cell_data(1,1+i) = {fread(f,1,'double')};
            end
            if flgChild == 69
                flgCoeff = 7;
                %cell_data(1)={'[校正係数]'};
                cell_data(1)={'[Calibration Coeff.]'};
            else
                flgCoeff = 8;
                %cell_data(1)={'[オフセット]'};
                cell_data(1)={'[Offset]'};
            end
            strSndBuf = cell_data;
%チャンネル名称の抽出
        elseif flgChild == 49                               %チャンネル名称
            int8_array =zeros(1,40,'uint32');
            flgCoeff = 4;
            for i = 1:ch
                for ii = 1:40
                    int8_array(ii) = fread(f,1,'uchar');
                end

                cell_data(i+1)={''};
                if(isempty(nonzeros(int8_array))==0)
                    cell_data(i+1) = {native2unicode(nonzeros(int8_array)')};
                end
            end
            %cell_data(1)={'[CH名称]'};
            cell_data(1)={'[CH Name]'};
            strSndBuf = cell_data;
            clear int8_array
%レンジ文字列の抽出
        elseif flgChild == 51
            flgCoeff = 6;
            int8_array =zeros(1,20,'uint32');
            %CSV旧の場合
            if g_CsvFormat == 0
                for i = 1:ch
                    for ii = 1:20
                        int8_array(ii) = fread(f,1,'uchar');
                    end
                    int8_array=nonzeros(int8_array)';
                    char_array=zeros(size(int8_array,2),1,'uint32');

                        for ii = 1:size(int8_array,2)
                            if( (48<=int8_array(ii) && int8_array(ii)<=57) || int8_array(ii)==46)   %0～9とピリオド(小数点)
                                char_array(ii)=int8_array(ii);
                            elseif(int8_array(ii)==32)

                            elseif(int8_array(ii)==75 || int8_array(ii)==107)   %k，K(キロ)の時
                                k_flag=1000;
                                break;
                            elseif(int8_array(ii)==79 || int8_array(ii)==111)   %o，O(OFF)の時
                                char_array(ii)=0;
                                break;
                            else
                                k_flag=1;
                                break;
                            end
                        end
                        cell_data(i+1)={0};
                        if(isempty(nonzeros(char_array))==0)
                            cell_data(i+1) = {single(str2double(native2unicode(nonzeros(char_array)'))*k_flag)'};
                        end
                end
                %cell_data(1)={'[レンジ]'};
                cell_data(1)={'[Range]'};
                clear char_array
            %CSV標準の場合
            else
                for i = 1:ch
                    for ii = 1:20
                        int8_array(ii) = fread(f,1,'uchar');
                    end

                    cell_data(i+1)={''};
                    if(isempty(nonzeros(int8_array))==0)
                        cell_data(i+1) = {native2unicode(nonzeros(int8_array)')};
                    end
                end
                %cell_data(1)={'[レンジ]'};
                cell_data(1)={'[Range]'};
            end

            strSndBuf = cell_data;
            clear int8_array
%ローパスフィルタ文字列の抽出
        elseif flgChild == 53
            flgCoeff = 9;
            int8_array =zeros(1,20,'uint32');

            for i = 1:ch
                for ii = 1:20
                    int8_array(ii) = fread(f,1,'uchar');
                end

                cell_data(i+1)={''};
                if(isempty(nonzeros(int8_array))==0)
                    cell_data(i+1) = {native2unicode(nonzeros(int8_array)')};
                end
            end
            %cell_data(1)={'[ローパスフィルタ]'};
            cell_data(1)={'[Low Pass Filter]'};
            strSndBuf = cell_data;
            clear int8_array
%ハイパスフィルタ文字列の抽出
        elseif flgChild == 54
            flgCoeff = 10;
            int8_array =zeros(1,20,'uint32');

            for i = 1:ch
                for ii = 1:20
                    int8_array(ii) = fread(f,1,'uchar');
                end

                cell_data(i+1)={''};
                if(isempty(nonzeros(int8_array))==0)
                    cell_data(i+1) = {native2unicode(nonzeros(int8_array)')};
                end
            end
            %cell_data(1)={'[ハイパスフィルタ]'};
            cell_data(1)={'[High Pass Filter]'};
            strSndBuf = cell_data;
            clear int8_array
%デジタルフィルタ文字列の抽出
        elseif flgChild == 71
            flgCoeff = 11;
            int8_array =zeros(1,40,'uint32');

            for i = 1:ch
                for ii = 1:40
                    int8_array(ii) = fread(f,1,'uchar');
                end

                cell_data(i+1)={''};
                if(isempty(nonzeros(int8_array))==0)
                    cell_data(i+1) = {native2unicode(nonzeros(int8_array)')};
                end
            end
            %cell_data(1)={'[デジタルフィルタ]'};
            cell_data(1)={'[Digital Filter]'};
            strSndBuf = cell_data;
            clear int8_array
%CHモードの抽出
        elseif flgChild == 56
            flgCoeff = 12;
            int8_array =zeros(1,40,'uint32');

            for i = 1:ch
                for ii = 1:40
                    int8_array(ii) = fread(f,1,'uchar');
                end

                cell_data(i+1)={''};
                if(isempty(nonzeros(int8_array))==0)
                    cell_data(i+1) = {native2unicode(nonzeros(int8_array)')};
                end
            end
            %cell_data(1)={'[CHモード]'};
            cell_data(1)={'[CH Mode]'};
            strSndBuf = cell_data;
            clear int8_array
%ゲージ率
        elseif flgChild == 57
            flgCoeff = 13;
            int8_array =zeros(1,20,'uint32');

            for i = 1:ch
                for ii = 1:20
                    int8_array(ii) = fread(f,1,'uchar');
                end

                cell_data(i+1)={''};
                if(isempty(nonzeros(int8_array))==0)
                    cell_data(i+1) = {native2unicode(nonzeros(int8_array)')};
                end
            end
            %cell_data(1)={'[ゲージ率]'};
            cell_data(1)={'[Guuji Rate]'};
            strSndBuf = cell_data;
            clear int8_array
%ZERO，ZERO値
        elseif flgChild == 72
            flgCoeff = 14;
            int8_array =zeros(1,20,'uint32');

            for i = 1:ch
                for ii = 1:20
                    int8_array(ii) = fread(f,1,'uchar');
                end

                if(isempty(nonzeros(int8_array))==0)
                    StrZeroNum = {native2unicode(nonzeros(int8_array)')};
                end
                for ii = 1:20
                    int8_array(ii) = fread(f,1,'uchar');
                end

                if(isempty(nonzeros(int8_array))==0)
                    StrZeroMode = {native2unicode(nonzeros(int8_array)')};
                end

                cell_data(i+1)={''};
                %分解しやすいように，','で区切る
                cell_data(i+1) = strcat(StrZeroNum,',',StrZeroMode);
            end
            cell_data(1)={'[ZERO]'};
            strSndBuf = cell_data;
            clear int8_array
        else
            strSndBuf = 0;
        end
    elseif flgParent == 16 % データ部データヘッダ部

%測定開始時刻の抽出
%csvデータは cell(1,1)=20xx/xx/xx，cell(1,2)=yy:yy:yyで表現している
%バイナリは，20xxxxxxyyyyyyであるため，区切り(/，:)を追加する

        if  flgChild == 3 % 測定開始時刻
            flgCoeff = 9;
            header_array = fread(f,16,'uchar');
            for n=1:size(header_array,1)
                if(48>header_array(end,1) || 57<header_array(end,1))
                    header_array(end,:)=[];
                else
                    break;
                end
            end
            if(isempty(header_array)==0)
                date_1=zeros(1,10);
                date_2=zeros(1,8);
                date_1(5)='/';  date_1(8)='/';
                date_2(3)=':';  date_2(6)=':';
                date_1(1,1:4)=header_array(1:4,1);  date_1(1,6:7)=header_array(5:6,1);  date_1(1,9:10)=header_array(7:8,1);
                date_2(1,1:2)=header_array(9:10,1);  date_2(1,4:5)=header_array(11:12,1);  date_2(1,7:8)=header_array(13:14,1);
                %cell_data(1) = {'[試験日時]'};
                cell_data(1) = {'[Test Date]'};
                cell_data(2)={native2unicode(date_1)};
                cell_data(3)={native2unicode(date_2)};
            end

            strSndBuf = cell_data;
            clear data_1;
            clear data_2;
            clear header_array;

%データ数/chの抽出
        elseif flgChild == 30 % 1ch当たりのデータ数
            flgCoeff = 10;
            ch_data=zeros(1,1,'double');
            header_array = fread(f,8,'uchar');

            for n=1:size(header_array,1)
               haeder_array(n)=native2unicode(header_array(size(header_array,1)-n+1));  %header_arrayは16進数
               ch_data=ch_data+double(floor(header_array(n)/16)*16^(2*(n-1)+1)+mod(header_array(n),16)*16^(2*(n-1)));   %16進数を10進数に変換
            end

            if(isempty(header_array)==0)
                %cell_data(1) = {'[集録データ数/CH]'};
                cell_data(1) = {'[Number of Samples/CH]'};
                cell_data(2)={ch_data};
            end
            strSndBuf = cell_data;
            clear header_array;

        elseif flgChild == 34       % MAX/MINデータ
            %KS2のVerが5以上ならボディバイト数は4
            if g_Ks2VerNum >= 5       % KS201.05以上の場合，ボディ部バイト数は4バイト
                flgDelta = 4;
            else
                flgDelta = 2;
            end
            strSndBuf = 0;
        elseif flgChild == 35       % MAX/MIN前後400データ
            flgDelta = 4;
            strSndBuf = 0;
        elseif flgChild == 36       % MAX/MIN発生ポイント
            %KS2のVerが5以上ならボディバイト数は4
            if g_Ks2VerNum >= 5       % KS201.05以上の場合，ボディ部バイト数は4バイト
                flgDelta = 4;
            else
                flgDelta = 2;
            end
            strSndBuf = 0;
        else
            flgDelta = 2;
            strSndBuf = 0;
        end
    elseif flgParent == 17 % 実際のデータ部分
        if flgChild == 1
            flgDelta = 4;
        else
            flgDelta = 8;
        end

        lngByte   = checkByteSize(strCharBuf);
        % CANの有無で、データの高さが変化
        if (isnan(tblInfo.CAN) == 1)
            lngDiv    = tblInfo.chAll * lngByte;
            lngHeight = smlSeek / lngDiv;
        else
            lngDiv = (tblInfo.chAll * lngByte) + (tblInfo.CAN * 8);
            lngHeight = smlSeek / lngDiv;
        end

        chAll = tblInfo.chAll + 1;
        ch = tblInfo.ch + 1;
        tblInfo.LngHeight = lngHeight;

        if flgDebug == 1
            %makeDispMessage(31,tblInfo);
        end
        try % エラートラップ
            array = zeros(lngHeight,chAll+tblInfo.CanChNum,'double');
            h = waitbar(0,makeDispMessage(32,tblInfo));

            if strcmp(tblInfo.machine,tblInfo.CmpMachine1) || strcmp(tblInfo.machine,tblInfo.CmpMachine2);
                if(tblInfo.chAll ~= 0)
                    val(tblInfo.chAll) =zeros;
                end
                tblInfo.ChNum =tblInfo.chAll;
            else
                if(tblInfo.ch ~= 0)
                    val(tblInfo.ch) =zeros;
                end
                tblInfo.ChNum =tblInfo.ch;
            end
            for i = 1:lngHeight
                %データ書き出し
                if g_IndexType == 0
                    if(g_StartNumber == 0)
                        array(i,1) = (i-1) / tblInfo.Hz;
                    else
                        array(i,1) = i / tblInfo.Hz;
                    end
                else
                    if(g_StartNumber == 0)
                        array(i,1) = (i-1);
                    else
                        array(i,1) = i;
                    end
                end
                valLabel = 'float32';

                if(strcmp(strCharBuf,'Int'))
                    valLabel = 'int16';
                elseif(strcmp(strCharBuf,'Long')) %ver1.01
                    valLabel = 'int32';
                elseif(strcmp(strCharBuf,'Double'))
                    valLabel = 'double';
                end

                if strcmp(valLabel, 'float32')
                    for jj = 1:tblInfo.ChNum
                       val(jj) = str2double(sprintf('%.7G', fread(f,1,valLabel)));
                    end
                else
                    val = fread(f,tblInfo.ChNum,valLabel)';
                end

                %アナログCHデータのみ読み込む Ver0103
                array(i,2:ch) = tblCoeff(1:ch-1).* val(1:ch-1) + tblOffset(1:ch-1);

                %CANデータ読みこみ
                %CANの設定が無い場合
                SumCanChNum = 0;
                if (isnan(tblInfo.CAN) == 1)
                else
                    %集録CAN-ID数が1つでもあったら
                    if tblInfo.CAN ~= 0

                        %CANデータ処理用のデータ型保存配列のコピー Ver0103
                        CanChProcType = CanChDataType;

                        %CAN-ID数の設定
                        CanIdNum = tblInfo.CAN;

                        %CAN-IDデータの読み込み
                        CanIdData(1,1:CanIdNum) = fread(f,CanIdNum,'uint64=>uint64');

                        %ビックエンディアン用に事前にリトルエンディアンに変換した配列を用意する
                        CanIdData(2,1:CanIdNum) = swapbytes(CanIdData(1,1:CanIdNum));
                        CanIdData(2,1:CanIdNum) = bitshift(CanIdData(2,1:CanIdNum),-8*(8-CanIdDataLen(1:CanIdNum)));

                        %CAN-IDデータを該当するCAN-CHデータへコピーする(エンディアンがリトルなら1行目，ビックなら2行目を読み込む)
                        CanChNum = 1;
                        for k = 1:CanIdNum
                            SumCanChNum = (CanChNum+CanIdChNum(k)-1);
                            CanChData(CanChNum:SumCanChNum) = CanIdData(CanIdEndian(k),k);
                            CanChNum = SumCanChNum+1;
                        end

                        %不必要なビット列削除のため右側へシフト
                        CanChData(1:SumCanChNum) = bitshift(CanChData(1:SumCanChNum),CanChBitShiftR(1:SumCanChNum));

                        %必要なビットだけ残すためマスク
                        CanChData(1:SumCanChNum) = bitand(CanChData(1:SumCanChNum), CanChBitMask(1:SumCanChNum));

                        %CAN-CH数分データ処理
                        for kk = 1:SumCanChNum

                            %Signed型の場合
                            if (CanChDataType(kk) == 0)

                                %有効ビット長の最後が1だったら，符号が負
                                if( bitget(CanChData(kk), CanChBitLen(kk)))

                                    %Signedマスクにより負のデータに変換
                                    SignedCanChData(kk) = typecast(bitor(bitset(CanChData(kk),CanChBitLen(kk)+1), CanChSignedMask(kk)),'int64');

                                    %データタイプ型を処理用に変更
                                    CanChProcType(kk) = 4;
                                else
                                end
                            %UnSigned型の場合
                            elseif(CanChDataType(kk) == 1)
                            %Float型の場合
                            elseif(CanChDataType(kk) == 2)

                                %uint64型からFloatに読み込み型の変更
                                FloatCanData = typecast(CanChData(kk),'single');

                                %Float型の範囲を超えていたらデータは0とする
                                if( abs(FloatCanData(1,1))<FloatMin || abs(FloatCanData(1,1))>FloatMax )
                                    FloatCanData(1,1) = 0;
                                end

                                %(1,2)はごみデータ，(1,1)がFloat型に変換されたデータ
                                %Ver0103 float型データの有効
                                DoubleCanChData(kk) =  str2double(sprintf('%.7G', FloatCanData(1,1)));

                                %データタイプ型を処理用に変更
                                CanChProcType(kk) = 3;
                            %Double型の場合
                            else

                                %uint64型からDoubleに読み込み型の変更
                                DoubleCanData = typecast(CanChData(kk),'double');

                                %Double型の範囲を超えていたらデータは0とする
                                if( abs(DoubleCanData(1,1))<DoubleMin || abs(DoubleCanData(1,1))>DoubleMax )
                                    DoubleCanData = 0;
                                end

                                %Double型データの設定
                                DoubleCanChData(kk) = DoubleCanData;
                            end
                        end

                        %Double型のデータとして型変換しながら設定
                        array(i,ch+1:ch+SumCanChNum)= ...
                            (CanChProcType(1:SumCanChNum) == 0 | CanChProcType(1:SumCanChNum) == 1).*cast(CanChData(1:SumCanChNum),'double')'...
                            + (CanChProcType(1:SumCanChNum) == 3).*DoubleCanChData(1:SumCanChNum)'...
                            + (CanChProcType(1:SumCanChNum) == 4).*cast(SignedCanChData(1:SumCanChNum),'double')';

                        %校正係数とオフセットにより物理量に変換
                        array(i,ch+1:ch+SumCanChNum) = array(i,ch+1:ch+SumCanChNum).* CanChCoeffs(1:SumCanChNum) + CanChOffset(1:SumCanChNum);
                    end
                end

                %デジタルCHデータの読み込み
                for j = 1:(chAll - ch)
                    if strcmp(strCharBuf,'Int')
                        array(i,ch+SumCanChNum+j) = fread(f,1,'uint16');
                    else
                        array(i,ch+SumCanChNum+j) = fread(f,1,valLabel);
                    end
                end
                if fix(rem(i,100)) < 1
                    waitbar(i / lngHeight);
                end
            end % i
            close(h);clear h;
            flgCoeff = 3;
            strSndBuf = array;

            clear CanIdMax;        %CAN-IDの最大数
            clear CanChMax;        %CAN-CHの最大数
            clear DoubleMax;       %Double型最大値
            clear DoubleMin;       %Double型最小値
            clear FloatMax;        %Float型最大値
            clear FloatMin;        %Float型最小値
            clear CanIdEndian;     %CAN-IDエンディアン
            clear CanIdDataLen;    %CAN-IDデータ長
            clear CanIdChNum;      %CAN-IDのCH数
            clear CanChBitShiftR;  %CAN-CH分解用右側ビットシフト
            clear CanChStBit;      %CAN-CHスタートビット
            clear CanChDataType;   %CAN-CHデータ型
            clear CanChBitLen;     %CAN-CHビット長
            clear CanChBitMask;    %CAN-CHビットマスク
            clear CanChSignedMask; %CAN-CHSigned型変換マスク
            clear CanChCoeffs;     %CAN-CH校正係数
            clear CanChOffset;     %CAN-CHオフセット
            clear CanChData;       %CAN-CHデータ(uint64)
            clear SignedCanChData; %CAN-CHデータ(int64)
            clear FloatCanChData;  %CAN-CHデータ(float)
            clear DoubleCanChData; %CAN-CHデータ(double)
        catch
            if tblInfo.MATLAB_Ver >= 6.5
                err = lasterror;
                tblInfo.err.message = err.message;
                tblInfo.err.identifier = err.identifier;
                tblInfo.err.stack = err.stack;
            else
                [message,msgid] = lasterr;
                tblInfo.err.message = message;
                tblInfo.err.identifier = msgid;
                disp(lasterr);
            end
            strSndBuf = tblInfo;
            % メモリエラー判定
            [~, num] = split_str(err.message, 'MEMORY');
            if num > 1
                flgCoeff = 999;
            else
                flgCoeff = 111;
            end
            return
        end
    elseif flgParent== 18
        if flgChild == 25
            flgDelta = 8;
        else
            flgDelta = 4;
        end
        strSndBuf = 0;
    else
        strSndBuf = 0;
    end

    if flgDelta ==  4
        delta = delta + tblInfo.InfoSeek + 2 + smlSeek;      %  8 = 1 + 1 + 4(body) + 2
    elseif flgDelta == 8
        delta = delta + tblInfo.InfoSeek + 6 + smlSeek;      % 12 = 1 + 1 + 8(body) + 2
    else
        delta = delta + tblInfo.InfoSeek + smlSeek;          %  6 = 1 + 1 + 2(body) + 2
    end

%--------------------------------------------------------------------------
%% makeChStrings - カンマで区切られた文字列を生成。
%    引数
%       pos       ... 走査位置
%       strRcvBuf ... 連結文字列
%       array     ... 対象文字列
%       headStr   ... 先頭につける文字列
%       midStr    ... それ以降の区切り文字列
%    戻り値
%       strSndBuf ... 連結した文字列
function strSndBuf = makeChStrings(pos,strRcvBuf,array,headStr,midStr)
    if pos == 1
        strSndBuf = [headStr,num2str(array)];
    else
        strSndBuf = [strRcvBuf,midStr,num2str(array)];
    end


%--------------------------------------------------------------------------
%% checkCharacter - 指定されたデータ型を返す。
%    引数
%       check     ... チェック用データ
%    戻り値
%       strSndBuf ... 該当のデータタイプ
function strSndBuf = checkCharacter(check)

    switch check
     case 0
      strSndBuf = 'Char';
     case 1
      strSndBuf = 'Int';
     case 2
      strSndBuf = 'Long';
     case 3
      strSndBuf = 'Float';
     case 4
      strSndBuf = 'Double';
     case 5
      strSndBuf = 'UChar';
     case 6
      strSndBuf = 'UShort';
     case 7
      strSndBuf = 'ULong';
     case 8
      strSndBuf = 'Int64';
     case 9
      strSndBuf = 'UInt64';
     otherwise
      strSndBuf = check;
    end


%--------------------------------------------------------------------------
%% checkByteSize - 指定されたデータ型のバイト数を返す。
%    引数
%       check     ... チェック用データ
%    戻り値
%       strSndBuf ... 該当のバイトタイプ
function strSndBuf = checkByteSize(check)

    if strcmp(check,'Char') || strcmp(check,'UChar')
        strSndBuf = 1;
    elseif strcmp(check,'Int') || strcmp(check,'UShort')
        strSndBuf = 2;
    elseif strcmp(check,'Long') || strcmp(check,'ULong') || strcmp(check,'Float') %| strcmp(check,'Double')
        strSndBuf = 4;
    else
        strSndBuf = 8;
    end

%------------------------------------------------------------
%% split_str():
%
% usage :
%    split_str(str,Delm);
%    tbls = split_str(str,Delm);
%    [tbls,num] = split_str(str,Delm);
%
% arguments:
%    str  ... original Character strings
%    Delm ... delimiter
%
% return values
%    tbls ... Character array
%    num  ... number of elements of character array
function [tbls,num] = split_str(str,Delm)
    tbls = {};

    [pos,rem] = strtok(str,Delm);
    if isempty(rem)
        tbls = str;
        num = 1;
        return;
    end

    tbls{1} = pos;
    num = 1;
    while(~isempty(rem))
        num = num + 1;
        [tbls{num}, rem] = strtok(rem,Delm);
    end

%--------------------------------------------------------------------------
%% e4aread();
function [e4X, Header, ErrNo] = e4read(file)

    global g_E4aVerNum;     %E4AのVer情報

    global g_LanguageType;  %本スクリプト実行時のコマンドプロンプト上に表示する言語を切り替えます
                            %0:日本語     1:英語

    tblInfo = [];

    delm = '.';

    tblInfo.Error{1}       = 'MATLAB:ksread3:FileName';
    tblInfo.Error{2}       = 'MATLAB:ksread3:Argument';
    tblInfo.Error{3}       = 'MATLAB:ksread3:Argument';
    tblInfo.Error{11}      = 'MATLAB:ksread3:FileExist';
    tblInfo.Error{14}      = 'MATLAB:ksread3:FileExtension';
    tblInfo.Error{15}      = 'MATLAB:ksread3:FileExist';
    tblInfo.Error{21}      = 'MATLAB:ksread3:OutOfMemory';
    tblInfo.Error{22}      = 'MATLAB:ksread3:Error Ocurred';
    tblInfo.err.message    = '';
    tblInfo.err.identifier = '';
    tblInfo.err.stack      = [];
    tblInfo.CmpExt       = 'e4a';
    e4X = 0;
    Header = 0;

% MATLABのversionチェック
    vers = version;
    tblInfo.MATLAB_Ver   = str2double(vers(1:3));
    tblInfo.HeadSeek     = 960; % 固定長ヘッダ部の大きさ

% MATLABのVer(R2008以降)によって言語切り替えが困難のため，パラメータで設定する
    tblInfo.CmpLang = 'jhelp';
    if g_LanguageType == 0
        tblInfo.Lang = 'jhelp';
    else
        tblInfo.Lang = 'Dummy';
    end
  % (1)引数が指定されていない場合
    if nargin < 1 || isempty(file)
        ErrNo = 1;
        return
    elseif nargin > 1
        % (2)引数の数が適切でない
        ErrNo = 2;
        return
    end

    [tbls,num] = split_str(file,delm);
    % (3)拡張子が無い
    if num < 2
        ErrNo = 3;
        return
    end
    tblInfo.ext = lower(tbls{2}); % 取得した拡張子

    % (14)拡張子が異なる
    if(strcmpi(tblInfo.CmpExt, tblInfo.ext) == 0)
        ErrNo = 14;
        return
    end

    fid = fopen(file,'r');
    % (11)ファイルが存在しない場合
    if fid < 0
        ErrNo = 11;
        return
    end

    %E4Aよりテキスト情報の取得
    tblInfo = getE4aInfo(fid,tblInfo);

    %E4Aのバージョン番号の取得
    VerStr = split_str(tblInfo.version,delm);
    g_E4aVerNum = str2double(cell2mat(VerStr(2)));

    %ID情報の取得
    CanIdDataLen = getIdInfo(fid,tblInfo);

    %データ数の取得
    tblInfo.e4XLen = getDataNum(fid,tblInfo);

    %CH条件の取得
    [CanChStBit, CanChBitLen, CanChDataType, CanChEndian, CanChIdNo, CanChChNo, CanChEdxId, CanChUnitStr, CanChCoeffs, CanChOffset, CanChName] = getChInfo(fid,tblInfo);

    %CAN-CH分解に必要な変数の用意
    [CanChBitShiftR, CanChBitMask, CanChSignedMask, CanChDataLen] = getCanChDecompPrm(tblInfo, CanChStBit, CanChBitLen, CanChIdNo, CanIdDataLen);

    %集録データの取得
    [e4X, e4XIndex, ErrNo]= getCanData(fid, tblInfo, CanChIdNo, CanChEndian, CanChDataType, CanChBitLen, ...
                                CanChBitShiftR, CanChBitMask, CanChSignedMask, CanChDataLen, CanChCoeffs, CanChOffset);

    %エラー発生の場合処理を飛ばす
    if(ErrNo ~= 0)
        fclose(fid);
        return
    end

    %不必要な行列の削除
    clear CanChBitLen
    clear CanChBitMask
    clear CanChBitShiftR
    clear CanChDataLen
    clear CanChDataType
    clear CanChEndian
    clear CanChIdNo
    clear CanChSignedMask
    clear CanChStBit
    clear CanIdDataLen

    %ヘッダ情報の作成
    Header = getHeaderInfo(tblInfo, CanChChNo, CanChEdxId, CanChCoeffs, CanChOffset, CanChName, CanChUnitStr, e4XIndex);

    %不必要な行列の削除
    clear CanChChNo
    clear CanChEdxId
    clear CanChCoeffs
    clear CanChOffset
    clear CanChName
    clear CanChUnitStr

    fclose(fid);

%--------------------------------------------------------------------------
%%

function [tblInfo, ErrNo] = e4readHeader(file)


    global g_LanguageType;  %本スクリプト実行時のコマンドプロンプト上に表示する言語を切り替えます
                            %0:日本語     1:英語
    tblInfo = [];

    delm = '.';

    tblInfo.Error{1}       = 'MATLAB:ksread3:FileName';
    tblInfo.Error{2}       = 'MATLAB:ksread3:Argument';
    tblInfo.Error{3}       = 'MATLAB:ksread3:Argument';
    tblInfo.Error{11}      = 'MATLAB:ksread3:FileExist';
    tblInfo.Error{14}      = 'MATLAB:ksread3:FileExtension';
    tblInfo.Error{15}      = 'MATLAB:ksread3:FileExist';
    tblInfo.Error{21}      = 'MATLAB:ksread3:OutOfMemory';
    tblInfo.Error{22}      = 'MATLAB:ksread3:Error Ocurred';
    tblInfo.err.message    = '';
    tblInfo.err.identifier = '';
    tblInfo.err.stack      = [];
    tblInfo.CmpExt       = 'e4a';

% MATLABのversionチェック
    vers = version;
    tblInfo.MATLAB_Ver   = str2double(vers(1:3));
    tblInfo.HeadSeek     = 960; % 固定長ヘッダ部の大きさ

% MATLABのVer(R2008以降)によって言語切り替えが困難のため，パラメータで設定する
    tblInfo.CmpLang = 'jhelp';
    if g_LanguageType == 0
        tblInfo.Lang = 'jhelp';
    else
        tblInfo.Lang = 'Dummy';
    end
  % (1)引数が指定されていない場合
    if nargin < 1 || isempty(file)
        ErrNo = 1;
        return
    elseif nargin > 1
        % (2)引数の数が適切でない
        ErrNo = 2;
        return
    end

    [tbls,num] = split_str(file,delm);
    % (3)拡張子が無い
    if num < 2
        ErrNo = 3;
        return
    end
    tblInfo.ext = lower(tbls{2}); % 取得した拡張子

    % (14)拡張子が異なる
    if(strcmpi(tblInfo.CmpExt, tblInfo.ext) == 0)
        ErrNo = 14;
        return
    end

    fid = fopen(file,'r');
    % (11)ファイルが存在しない場合
    if fid < 0
        ErrNo = 11;
        return
    end

    %E4Aよりテキスト情報の取得
    tblInfo = getE4aInfo(fid,tblInfo);

    %データ数の取得
    tblInfo.e4XLen = getDataNum(fid,tblInfo);

    fclose(fid);
%--------------------------------------------------------------------------
%% ID情報の取得
%    引数
%        fid     ... ファイルポインタオブジェクト
%        tblInfo ... 構造体変数
%    戻り値
%        IdLen    ... CANIDデータ長配列
function IdLen = getIdInfo(fid,tblInfo)

    IdLen = zeros(1,tblInfo.TransIdInfoNum,'int32');

    SeekByte = tblInfo.HeadSeek...
                + (tblInfo.TransStsSize*tblInfo.TransStsNum)...
                + (tblInfo.TransNodeSize*tblInfo.TransNodeNum);
    fseek(fid,SeekByte,'bof');

    fseek(fid,8,'cof');
    IdLen(1) = fread(fid,1,'uint8=>int32');

    for i = 1:(tblInfo.TransIdInfoNum-1)
        fseek(fid,(tblInfo.TransIdInfoSize-1),'cof');
        IdLen(i+1) = fread(fid,1,'uint8=>int32');
    end

%--------------------------------------------------------------------------
%% CAN-CH情報の取得
%    引数
%        fid     ... ファイルポインタオブジェクト
%        tblInfo ... 構造体変数
%    戻り値
%        CanChStBit     ... CAN-CHのスタートビット
%        CanChBitLen    ... CAN-CHのビット長
%        CanChDataType  ... CAN-CHのデータ型
%        CanChEndian    ... CAN-CHのエンディアン
%        CanChIdNo      ... CAN-CHのID番号
%        CanChChNo      ... CAN-CHのCH番号
%        CanChEdxId     ... CAN-CHのEDXのID番号
%        CanChUnitStr   ... CAN-CHの単位文字列
%        CanChCoeffs    ... CAN-CHの校正係数
%        CanChOffset    ... CAN-CHのオフセット
%        CanChName      ... CAN-CHのCH名称
function [CanChStBit, CanChBitLen, CanChDataType, CanChEndian, CanChIdNo, CanChChNo, CanChEdxId, CanChUnitStr, CanChCoeffs, CanChOffset, CanChName] = getChInfo(fid,tblInfo)

    CanChStBit = zeros(1,tblInfo.TransChStsNum,'uint32');
    CanChBitLen = zeros(1,tblInfo.TransChStsNum,'uint32');
    CanChDataType = zeros(1,tblInfo.TransChStsNum,'uint32');
    CanChEndian = zeros(1,tblInfo.TransChStsNum,'uint32');
    CanChIdNo = zeros(1,tblInfo.TransChStsNum,'uint32');
    CanChChNo = zeros(1,tblInfo.TransChStsNum,'uint32');
    CanChEdxId = zeros(1,tblInfo.TransChStsNum,'uint32');
    CanChUnitStr(tblInfo.TransChStsNum) = {''};
    CanChCoeffs = zeros(1,tblInfo.TransChStsNum,'double');
    CanChOffset = zeros(1,tblInfo.TransChStsNum,'double');
    CanChName(tblInfo.TransChStsNum) = {''};

    SeekByte = tblInfo.HeadSeek...
                + (tblInfo.TransStsSize*tblInfo.TransStsNum)...
                + (tblInfo.TransNodeSize*tblInfo.TransNodeNum)...
                + (tblInfo.TransIdInfoSize*tblInfo.TransIdInfoNum);
    fseek(fid,SeekByte,'bof');

    for i = 1:tblInfo.TransChStsNum
        CanChStBit(i) = fread(fid,1,'uint8=>int32');
        CanChBitLen(i) = fread(fid,1,'uint8=>int32');
        CanChDataType(i) = fread(fid,1,'uint8=>int32');

        fseek(fid,2,'cof');

        CanChEndian(i) = fread(fid,1,'uint8=>int32');

        fseek(fid,1,'cof');

        CanChEdxId(i) = fread(fid,1,'uint8=>int32');

        CanChIdNo(i) = fread(fid,1,'int16=>int32');
        CanChChNo(i) = fread(fid,1,'int16=>int32');

        uchar_array = fread(fid,10,'uchar');
        CanChUnitStr(i) = cellstr(native2unicode(uchar_array'));

        fseek(fid,2,'cof');

        CanChCoeffs(i) = fread(fid,1,'double');
        CanChOffset(i) = fread(fid,1,'double');

        uchar_array = fread(fid,44,'uchar');
        CanChName(i) = cellstr(native2unicode(uchar_array'));

        fseek(fid,12,'cof');
    end

%--------------------------------------------------------------------------
%% CAN-CH分解用の変数の取得
%    引数
%        tblInfo      ... 構造体変数
%        CanChStBit   ... CAN-CHスタートビット
%        CacChBitLen  ... CAN-CHのビット長
%        CanChDataLen ... CAN-CHに該当するIDのデータ長
%    戻り値
%        CanChBitShiftR     ... CAN-CHのビット長
%        CanChBitMask       ... CAN-CHのデータ型
%        CanChSignedMask    ... CAN-CHのエンディアン
%        CanChIdNo          ... CAN-CHのID番号
%        CanIdDataLen       ... CAN-IDのデータ長
function [CanChBitShiftR, CanChBitMask, CanChSignedMask, CanChDataLen] = getCanChDecompPrm(tblInfo, CanChStBit, CanChBitLen, CanChIdNo, CanIdDataLen)

    CanChNum = tblInfo.TransChStsNum;

    CanChBitShiftR = zeros(1,CanChNum,'int32');
    CanChBitMask = zeros(1,CanChNum,'uint64');
    CanChSignedMask = zeros(1,CanChNum,'uint64');
    CanChDataLen = zeros(1,CanChNum,'int32');

    for i = 1:CanChNum
        %Signed型変換用マスク行列の初期化
        CanChSignedMask(i) = cast(hex2dec('FFFFFFFFFFFFFFFF'), 'uint64');

        %CAN-CH変換用右側へのビットシフト行列の設定
        CanChBitShiftR(i) = cast(CanChStBit(i),'int32');
        CanChBitShiftR(i) = CanChBitShiftR(i) * -1;

        %マスクビットとSignedマスクビットの設定
        for kk = 1:CanChBitLen(i)
            CanChBitMask(i) = bitset(CanChBitMask(i), kk);
            CanChSignedMask(i) = bitset(CanChSignedMask(i), kk, 0);
        end
    end

    for i = 1:CanChNum
        CanChDataLen(i) = CanIdDataLen(CanChIdNo(i)+1);
    end

%--------------------------------------------------------------------------

%% CANデータ数の取得
%    引数
%        fid     ... ファイルポインタオブジェクト
%        tblInfo ... 構造体変数
%    戻り値
%        e4XLen  ... E4aデータ行列の長さ
function e4XLen = getDataNum(fid,tblInfo)

    %CANデータ部の最終データまでのバイト数を設定
    SeekByte = tblInfo.HeadSeek...
                + (tblInfo.TransStsSize*tblInfo.TransStsNum)...
                + (tblInfo.TransNodeSize*tblInfo.TransNodeNum)...
                + (tblInfo.TransIdInfoSize*tblInfo.TransIdInfoNum)...
                + (tblInfo.TransChStsSize*tblInfo.TransChStsNum)...
                + (tblInfo.CanDataSize*(tblInfo.DataNum-1));

    %最後のCANデータまで読み飛ばす
    fseek(fid,SeekByte,'bof');

    %ID情報番号(2バイト)と予約(2バイト)を読み飛ばす
    fseek(fid,4,'cof');

    %最終の集録カウンタ値の取得
    e4XLen = fread(fid, 1, 'uint64=>uint64');

    e4XLen = cast(e4XLen, 'double') + 1;
%--------------------------------------------------------------------------
%% CANデータの取得
%    引数
%        fid             ... ファイルポインタオブジェクト
%        tblInfo         ... 構造体変数
%        CanChIdNo       ... CAN-CHのID番号
%        CanChEndian     ... CAN-CHのエンディアン
%        CanChDataType   ... CAN-CHのデータ型
%        CanChBitLen     ... CAN-CHのビット長
%        CanChBitShiftR  ... CAN-CHのビット長
%        CanChBitMask    ... CAN-CHのデータ型
%        CanChSignedMask ... CAN-CHのエンディアン
%        CanIdDataLen    ... CAN-IDのデータ長
%        CanChCoeffs     ... CAN-CHの校正係数
%        CanChOffset     ... CAN-CHのオフセット
%    戻り値
%        e4XIndex ... CANデータ最終番号
%        e4X      ... CANデータ行列
function [e4X, e4XIndex, ErrNo] = getCanData(fid, tblInfo, CanChIdNo, CanChEndian, CanChDataType, CanChBitLen,...
                                    CanChBitShiftR, CanChBitMask, CanChSignedMask, CanChDataLen, CanChCoeffs, CanChOffset)

    global g_IndexType;     %読み込んだ集録データ行列の先頭列に付加するデータ形式を切り替えます
                            %0：時間      1：番号

    global g_StartNumber;   %読み込んだ集録データ行列の先頭列に付加するデータの先頭の開始番号を切り替えます。
                            %0：0始まり   1：1始まり

    e4X = 0;
    e4XIndex = 0;
    ErrNo = 0;

    %Double型最大値の設定
    DoubleMax = realmax('double');

    %Double型最小値の設定
    DoubleMin = realmin('double');

    %Float型最大値の設定
    FloatMax = realmax('single');

    %Float型最小値の設定
    FloatMin = realmin('single');

    %CAN-CH数の取得
    CanChNum = tblInfo.TransChStsNum;

    %CANデータ読み込み数(カウンタ値)
    CanDataReadNum = 1;

    %CANデータ読み込み終了フラグ
    CanDataReadEnd = 0;

    %CAN-CHデータ行列の初期化
    CanChData = zeros(1,CanChNum,'uint64');

    %Signed型データ行列の初期化
    SignedCanChData = zeros(CanChNum,1,'int64');

    %Double型データ行列の初期化
    DoubleCanChData = zeros(CanChNum,1,'double');

    %CAN-IDデータ行列の初期化
    CanIdData = zeros(1,CanChNum,'uint64');

    %CAN-CHデータ存在フラグ行列
    NonZerosIndex= zeros(1,CanChNum);

    %CANデータ部までのバイト数を設定
    SeekByte = tblInfo.HeadSeek...
                + (tblInfo.TransStsSize*tblInfo.TransStsNum)...
                + (tblInfo.TransNodeSize*tblInfo.TransNodeNum)...
                + (tblInfo.TransIdInfoSize*tblInfo.TransIdInfoNum)...
                + (tblInfo.TransChStsSize*tblInfo.TransChStsNum);

    %CANデータ部まで読み飛ばす
    fseek(fid,SeekByte,'bof');

    %ID番号の取得
    CanIdNo = fread(fid, 1, 'uint16');

    %予約(2バイト)を読み飛ばす
    fseek(fid,2,'cof');

    %集録カウンタ値の取得
    CanAgCnt = fread(fid, 1, 'uint64=>uint64');

    %CANデータの取得
    CanData = typecast(fread(fid, 8, 'uint8=>uint8'),'uint64');

    %予約(4バイト)読み飛ばす
    fseek(fid,4,'cof');

    %取得したCANID番号に該当するCAN-ID番号のインデックスを行列から取得
    Index=find(CanChIdNo == CanIdNo);

    %取得したインデックス番号にCANデータを設定
    CanIdData(Index) = CanData;

    %CAN-CHデータ存在フラグ行列をON
    NonZerosIndex(Index) = 1;

    %行列の長さを取得
    MatrixLen = cast(tblInfo.e4XLen,'double');

    try
        %CANデータ行列をNaNで初期化
        e4X(1:MatrixLen-tblInfo.StCnt,1:CanChNum) = NaN;
    catch
        ErrNo = 21;
        return
    end
    %ウェイトバーを表示
    h = waitbar(0,makeDispMessage(32,tblInfo));

%CANデータ読み込み処理部
    while(1)
        while (1)
            %前データのカウンタ値を設定
            CanPreAgCnt = CanAgCnt;

            %CAN-ID番号の取得
            CanIdNo = fread(fid, 1, 'uint16');

            %予約(2バイト)読み込む
            fseek(fid,2,'cof');

            %集録カウンタ値の取得
            CanAgCnt = fread(fid, 1, 'uint64=>uint64');

            %CANデータの取得
            CanData = typecast(fread(fid, 8, 'uint8=>uint8'),'uint64');

            %予約(4バイト)読み飛ばす
            fseek(fid,4,'cof');

            %前カウンタ値と現在のカウンタ値が異なる場合
            if(CanPreAgCnt ~= CanAgCnt)
                %現在のカウンタ値のCANデータの読み込みは終了し1データ分ポインタを戻す
                fseek(fid,-24,'cof');
                break;
            %前カウンタ値と現在のカウンタ値が一致した場合
            else
                %取得したCANID番号に該当するCAN-ID番号のインデックスを行列から取得
                Index=find(CanChIdNo == CanIdNo);

                %取得したインデックス番号にCANデータを設定
                CanIdData(Index) = CanData;

                %CAN-CHデータ存在フラグ行列をON
                NonZerosIndex(Index) = 1;

                %CANデータ読み込み数をインクリメント
                CanDataReadNum = CanDataReadNum + 1;
            end

            %CANデータ読み込み数がCANデータ数と一致したら
            if(CanDataReadNum == tblInfo.DataNum)

                %読み込み終了フラグをON
                CanDataReadEnd = 1;

                %前カウンタ値を現在のカウンタ値に設定(末端処理用)
                CanPreAgCnt = CanAgCnt;
                break;
            end
        end

        %ビックエンディアン用に事前にリトルエンディアンに変換した配列を用意する
        CanIdData(2,1:CanChNum) = swapbytes(CanIdData(1,1:CanChNum));
        CanIdData(2,1:CanChNum) = bitshift(CanIdData(2,1:CanChNum),-8*(8-CanChDataLen(1:CanChNum)));

       %CAN-CHデータへコピーする(エンディアンがリトルなら1行目，ビックなら2行目を読み込む)
        CanChData(CanChEndian==0) = CanIdData(1,CanChEndian==0);
        CanChData(CanChEndian==1) = CanIdData(2,CanChEndian==1);

        %不必要なビット列削除のため右側へシフト
        CanChData(1:CanChNum) = bitshift(CanChData(1:CanChNum),CanChBitShiftR(1:CanChNum));

        %必要なビットだけ残すためマスク
        CanChData(1:CanChNum) = bitand(CanChData(1:CanChNum), CanChBitMask(1:CanChNum));

        %Ver0103
        CanChProcType =CanChDataType;

        %CAN-CH数分データ処理
        for kk = 1:CanChNum

            %Signed型の場合
            if (CanChDataType(kk) == 0)
                %有効ビット長の最後が1だったら，符号が負
                if( bitget(CanChData(kk), CanChBitLen(kk)))

                    %Signedマスクにより負のデータに変換
                    SignedCanChData(kk) = typecast(bitor(bitset(CanChData(kk),CanChBitLen(kk)+1), CanChSignedMask(kk)),'int64');

                    %データタイプ型を処理用に変更
                    CanChProcType(kk) = 4;
                end
            %UnSigned型の場合
            elseif(CanChDataType(kk) == 1)
            %Float型の場合
            elseif(CanChDataType(kk) == 2)

                %uint64型からFloatに読み込み型の変更
                FloatCanData = typecast(CanChData(kk),'single');

                %Float型の範囲を超えていたらデータは0とする
                if( abs(FloatCanData(1,1))<FloatMin || abs(FloatCanData(1,1))>FloatMax )
                    FloatCanData(1,1) = 0;
                end

                %(1,2)はごみデータ，(1,1)がFloat型に変換されたデータ
                %Ver0103 float型データの有効
                DoubleCanChData(kk) =  str2double(sprintf('%.7G', FloatCanData(1,1)));

                %データタイプ型を処理用に変更
                CanChProcType(kk) = 3;
            %Double型の場合
            else

                %uint64型からDoubleに読み込み型の変更
                DoubleCanData = typecast(CanChData(kk),'double');

                %Double型の範囲を超えていたらデータは0とする
                if( abs(DoubleCanData(1,1))<DoubleMin || abs(DoubleCanData(1,1))>DoubleMax )
                    DoubleCanData = 0;
                end

                %Double型データの設定
                DoubleCanChData(kk) = DoubleCanData;
            end
        end

        %現在の行列インデックス番号の取得
        e4XIndex = cast(CanPreAgCnt,'double')+1-tblInfo.StCnt;

        %Double型のデータとして型変換しながら設定
        e4X(e4XIndex,1:CanChNum) = ...
            (CanChProcType(1:CanChNum) == 0 | CanChProcType(1:CanChNum) == 1).*cast(CanChData(1:CanChNum),'double')...
            + (CanChProcType(1:CanChNum) == 3).*DoubleCanChData(1:CanChNum)'...
            + (CanChProcType(1:CanChNum) == 4).*cast(SignedCanChData(1:CanChNum),'double')';

        %校正係数とオフセットにより物理量に変換
        e4X(e4XIndex,1:CanChNum) = e4X(e4XIndex,1:CanChNum).* CanChCoeffs(1:CanChNum) + CanChOffset(1:CanChNum);

        %CANデータが存在しない箇所をNaNで埋める
        e4X(e4XIndex,NonZerosIndex==0) = NaN;

        %CANデータ読み込み終了フラグがONなら終了
        if(CanDataReadEnd == 1)
            waitbar(100);
            break;
        end

        %CAN-IDデータ行列の初期化
        CanIdData = zeros(1,CanChNum,'uint64');

        %CAN-CHデータ行列の初期化
        CanChData = zeros(1,CanChNum,'uint64');

        %Signed型データ行列の初期化
        SignedCanChData = zeros(CanChNum,1,'int64');

        %Double型データ行列の初期化
        DoubleCanChData = zeros(CanChNum,1,'double');

        %CAN-CHデータ存在フラグ行列の初期化
        NonZerosIndex = zeros(1,CanChNum);

        if fix(rem(CanDataReadNum,100)) < tblInfo.DataNum
            waitbar(CanDataReadNum / tblInfo.DataNum);
        end
    end

    %不必要な行列の削除
    clear CanIdData
    clear CanChData
    clear DoubleCanChData
    clear SignedCanChData

    %前値保持処理
    %CANデータ行列の先頭のNaNを0へ
    e4X(1,isnan(e4X(1,:))==1) = 0;

    %CANデータ行列よりNaNでないインデックスを取得
    [n,m] = find(isnan(e4X)==0);

    %CHごとに前値保持処理
    for i = 1:CanChNum
        %i番目のCAN－CHのNaNでないインデックス行列を取得
        DataIndex = n(m==i);

        %numにインデックス数を取得
        [num,~]=size(DataIndex);

        for j = 1:(num-1)
            %NaNでないインデックス番号から次のNaNでないインデックス番号の1つ前までデータをコピー
            e4X((DataIndex(j):DataIndex(j+1)-1),i) = e4X(DataIndex(j),i);
        end

        %最後のNaNでないインデックス番号から行列の最後までデータをコピー
        e4X((DataIndex(num):e4XIndex),i) = e4X(DataIndex(num),i);
    end

    %時間分解能の取得
    TimeDiv = 1/tblInfo.Fs;

    %集録時間の取得
    RecTime = (e4XIndex)/tblInfo.Fs;

    %時間形式の場合
    if (g_IndexType==0)
        %0始まりの場合
        if(g_StartNumber == 0)
            xdiv=(0:TimeDiv:RecTime-TimeDiv)';
        %1始まりの場合
        else
            xdiv=(TimeDiv:TimeDiv:RecTime)';
        end
    %番号形式の場合
    else
        %0始まりの場合
        if(g_StartNumber == 0)
            xdiv=(0:e4XIndex-1)';
        %1始まりの場合
        else
            xdiv=(1:e4XIndex)';
        end
    end

    %データ番号行列とデータ行列を結合
    e4X=horzcat(xdiv,e4X);


    close(h);
    clear h;
%--------------------------------------------------------------------------
%% テキスト部の情報取得
%    引数
%        fid     ... ファイルポインタオブジェクト
%        tblInfo ... 構造体変数
%    戻り値
%        info    ... 情報を追加した構造体変数

function info = getE4aInfo(fid,tblInfo)


    uchar_array = fread(fid,20,'uchar');
    tblInfo.machine = native2unicode(uchar_array');

    uchar_array = fread(fid,12,'uchar');
    tblInfo.version = native2unicode(uchar_array');

    uchar_array = fread(fid,44,'uchar');
    tblInfo.title = native2unicode(uchar_array');

    uchar_array = fread(fid,16,'uchar');
    tblInfo.Date = native2unicode(uchar_array');

    tblInfo.DataNum = fread(fid,1,'int64');
    tblInfo.StCnt = fread(fid,1,'uint64');

    fseek(fid,8,'cof');

    tblInfo.CanTrgSize = fread(fid,1,'uint16');
    tblInfo.TransStsSize = fread(fid,1,'uint16');
    tblInfo.TransStsNum = fread(fid,1,'uint16');
    tblInfo.TransNodeSize = fread(fid,1,'uint16');
    tblInfo.TransNodeNum = fread(fid,1,'uint16');
    tblInfo.TransIdInfoSize = fread(fid,1,'uint16');
    tblInfo.TransIdInfoNum = fread(fid,1,'uint16');
    tblInfo.TransChStsSize = fread(fid,1,'uint16');
    tblInfo.TransChStsNum = fread(fid,1,'uint16');
    tblInfo.CanDataSize = fread(fid,1,'uint16');

    tblInfo.OverFlow = fread(fid,1,'uint32');
    tblInfo.Fs = fread(fid,1,'uint32');

    fseek(fid,8,'cof');

    uchar_array = fread(fid,12,'uchar');
    tblInfo.Language = native2unicode(uchar_array');

    fseek(fid,24,'cof');

    tblInfo.StTrgCnt = fread(fid,1,'uint64');
    tblInfo.EdTrgCnt = fread(fid,1,'uint64');
    clear header_array;

    info = tblInfo;



%--------------------------------------------------------------------------
%% ヘッダ情報の作成
%    引数
%        tblInfo      ... 構造体変数
%        CanChNo      ... CAN-CHスタートビット
%        CanChEdxId   ... CAN-CHのEDXのID番号
%        CacChCoeffs  ... CAN-CHのビット長
%        CanChOffset  ... CAN-CHに該当するIDのデータ長
%        CanChName    ... CAN-CH名称
%        CanChUnitStr ... CAN-CH単位文字列
%    戻り値
%        Header       ... ヘッダ情報

function Header = getHeaderInfo(tblInfo, CanChChNo, CanChEdxId, CanChCoeffs, CanChOffset, CanChName, CanChUnitStr, e4XIndex)

    global g_CsvFormat;     %ヘッダ情報形式の旧タイプ・標準タイプを切り替えます
                            %0：旧タイプ  1：標準タイプ
                            %旧タイプ：DAS-200Aの初期保存形式
                            %標準タイプ：Ver01.06で追加された新たなCSV保存形式
    %CAN-CH数の取得
    CanChNum = tblInfo.TransChStsNum;

%ヘッダ情報の作成
%各セルデータの初期化
        tblfileID = cell(1,CanChNum+1);
        tblfileID(:,:) = {''};
        %tblfileID(1,1) = {'[ID番号]'};
        tblfileID(1,1) = {'[ID No.]'};

        tblfileTitle = cell(1,CanChNum+1);
        tblfileTitle(:,:) = {''};
        %tblfileTitle(1,1) = {'[タイトル]'};
        tblfileTitle(1,1) = {'[Title]'};

        tblfileDate = cell(1,CanChNum+1);
        tblfileDate(:,:) = {''};
        %tblfileDate(1,1) = {'[試験日時]'};
        tblfileDate(1,1) = {'[Test Date]'};

        tblfileCh_num = cell(1,CanChNum+1);
        tblfileCh_num(:,:) = {''};
        %tblfileCh_num(1,1) = {'[測定CH数]'};
        tblfileCh_num(1,1) = {'[Number of Channels]'};

        tblfileDigi_ch = cell(1,CanChNum+1);
        tblfileDigi_ch(:,:) = {''};
        %tblfileDigi_ch(1,1) = {'[デジタル入力]'};
        tblfileDigi_ch(1,1) = {'[Digital Input]'};

        tblfileSf = cell(1,CanChNum+1);
        tblfileSf(:,:) = {''};
        %tblfileSf(1,1) = {'[サンプリング周波数(Hz)]'};
        tblfileSf(1,1) = {'[Sampling Frequency (Hz)]'};

        tblfileData_num = cell(1,CanChNum+1);
        tblfileData_num(:,:) = {''};
        %tblfileData_num(1,1) = {'[集録データ数/CH]'};
        tblfileData_num(1,1) = {'[Number of Samples/CH]'};

        tblfileTime = cell(1,CanChNum+1);
        tblfileTime(:,:) = {''};
        %tblfileTime(1,1) = {'[測定時間(sec)]'};
        tblfileTime(1,1) = {'[Time (sec)]'};

        tblName = cell(1,CanChNum+1);
        tblName(:,:) = {''};
        %tblName(1,1) = {'[CH名称]'};
        tblName(1,1) = {'[CH Name]'};

        tblNo = cell(1,CanChNum+1);
        tblNo(:,:) = {''};
        tblNo(1,1) = {'[CH No]'};

        tblrange = cell(1,CanChNum+1);
        tblrange(:,:) = {''};
        %tblrange(1,1) = {'[レンジ]'};
        tblrange(1,1) = {'[Range]'};

        tblCoeff_disp = cell(1,CanChNum+1);
        tblCoeff_disp(:,:) = {''};
        %tblCoeff_disp(1,1) = {'[校正係数]'};
        tblCoeff_disp(1,1) = {'[Calibration Coeff.]'};

        tblOffset_disp = cell(1,CanChNum+1);
        tblOffset_disp(:,:) = {''};
        %tblOffset_disp(1,1) = {'[オフセット]'};
        tblOffset_disp(1,1) = {'[Offset]'};

        tblUnit = cell(1,CanChNum+1);
        tblUnit(:,:) = {''};
        %tblUnit(1,1) = {'[単位]'};
        tblUnit(1,1) = {'[Unit]'};

        tblLowPass = cell(1,CanChNum+1);
        tblLowPass(:,:) = {''};
        %tblLowPass(1,1) = {'[ローパスフィルタ]'};
        tblLowPass(1,1) = {'[Low Pass Filter]'};

        tblHighPass = cell(1,CanChNum+1);
        tblHighPass(:,:) = {''};
        %tblHighPass(1,1) = {'[ハイパスフィルタ]'};
        tblHighPass(1,1) = {'[High Pass Filter]'};

        tblDigiFilter = cell(1,CanChNum+1);
        tblDigiFilter(:,:) = {''};
        %tblDigiFilter(1,1) = {'[デジタルフィルタ]'};
        tblDigiFilter(1,1) = {'[Digital Filter]'};

%ヘッダ情報の設定
    %文字列行列が空(0)のインデックス番号の取得
    StrEndIndex = find(tblInfo.title == 0,1,'first');

    %文字列が空の場合
    if StrEndIndex == 1
    %文字列がある場合
    else
        %余分な行列部を削除
        tblInfo.title(StrEndIndex:end) = [];

        %機器情報に設定
        tblfileTitle(1,2) = {tblInfo.title};
    end

    %文字列行列が空(0)のインデックス番号の取得
    StrEndIndex = find(tblInfo.machine == 0,1,'first');

    %文字列が空の場合
    if StrEndIndex == 1
    %文字列がある場合
    else
        %余分な行列部を削除
        tblInfo.machine(StrEndIndex:end) = [];

        %機器情報に設定
        tblfileID(1,2) = {tblInfo.machine};
    end

    %文字列行列が空(0)のインデックス番号の取得
    StrEndIndex = find(tblInfo.title==0,1,'first');

    %文字列が空の場合
    if StrEndIndex == 1
    %文字列がある場合
    else
        %余分な行列部を削除
        tblfileTitle(StrEndIndex:end) = [];

        %機器情報に設定
        tblfileTitle(1,2) = {tblInfo.title};
    end

    %一時的な文字行列を初期化
    TempChar = zeros(1,12);

    %試験日時データを○○○○△△△△→○○○○／△△／△△に変換
    TempChar(1:4) = tblInfo.Date(1:4);
    TempChar(5) = '/';
    TempChar(6:7) = tblInfo.Date(5:6);
    TempChar(8) = '/';
    TempChar(9:10) = tblInfo.Date(7:8);

    %文字列行列が空(0)のインデックス番号の取得
    StrEndIndex = find(TempChar==0,1,'first');

    %文字列が空の場合
    if StrEndIndex == 1
    %文字列がある場合
    else
        %余分な行列部を削除
        TempChar(StrEndIndex:end) = [];

        %機器情報に設定
        tblfileDate(1,2)={native2unicode(TempChar)};
    end

    %一時的な文字行列を初期化
    TempChar = zeros(1,12);

    %試験日時データを○○△△□□→○○：△△：□□に変換
    TempChar(1:2) = tblInfo.Date(9:10);
    TempChar(3) = ':';
    TempChar(4:5) = tblInfo.Date(11:12);
    TempChar(6) = ':';
    TempChar(7:8) = tblInfo.Date(13:14);

    %文字列行列が空(0)のインデックス番号の取得
    StrEndIndex = find(TempChar==0,1,'first');

    %文字列が空の場合
    if StrEndIndex == 1
    %文字列がある場合
    else
        %余分な行列部を削除
        TempChar(StrEndIndex:end) = [];

        %機器情報に設定
        tblfileDate(1,3)={native2unicode(TempChar)};
    end

    %測定CH数の設定
    tblfileCh_num(1,2) = {tblInfo.TransChStsNum};

    %サンプリング周波数の設定
    tblfileSf(1,2) = {tblInfo.Fs};

    %集録データ数の設定
    tblfileData_num(1,2) = {e4XIndex};

    %集録時間の取得
    RecTime = (e4XIndex)/tblInfo.Fs;

    %集録時間の設定
    tblfileTime(1,2) = {RecTime};

    %CAN-CH名称の設定
    tblName(2:end) = CanChName(1:end);

    %単位文字列の設定
    tblUnit(2:end) = CanChUnitStr(1:end);

    for i = 1:CanChNum
        %CH番号の設定
        if(CanChChNo(i) < 10)
            tblNo(i+1) = {strcat('E', int2str(CanChEdxId(i)), '-00', int2str(CanChChNo(i)))};
        elseif(CanChChNo(i) < 100)
            tblNo(i+1) = {strcat('E', int2str(CanChEdxId(i)), '-0', int2str(CanChChNo(i)))};
        else
            tblNo(i+1) = {strcat('E', int2str(CanChEdxId(i)), '-', int2str(CanChChNo(i)))};
        end

        %校正係数の設定
        tblCoeff_disp(i+1) = {CanChCoeffs(i)};

        %オフセットの設定
        tblOffset_disp(i+1) = {CanChOffset(i)};
    end

    %ヘッダ情報
    %旧タイプ
    if (g_CsvFormat == 0)
        %CH数が1の場合試験日時のヘッダ情報が3列あるため，その他のヘッダ情報を1列分増やす
        if (CanChNum == 1)
            tblfileID(3)={''};
            tblfileTitle(3)={''};
            tblfileCh_num(3)={''};
            tblfileDigi_ch(3)={''};
            tblfileSf(3)={''};
            tblfileData_num(3)={''};
            tblfileTime(3)={''};
            tblName(3)={''};
            tblNo(3)={''};
            tblrange(3)={''};
            tblCoeff_disp(3)={''};
            tblOffset_disp(3)={''};
            tblUnit(3)={''};
        end

        Header = [tblfileID; tblfileTitle; tblfileDate; tblfileCh_num; tblfileDigi_ch; tblfileSf;...
                        tblfileData_num; tblfileTime; tblName; tblNo; tblrange; tblCoeff_disp; tblOffset_disp; tblUnit; ];
    %標準タイプ
    else
        %CH数が1の場合試験日時のヘッダ情報が3列あるため，その他のヘッダ情報を1列分増やす
        if (CanChNum == 1)
            tblfileID(3)={''};
            tblfileTitle(3)={''};
            tblfileCh_num(3)={''};
            tblfileSf(3)={''};
            tblfileData_num(3)={''};
            tblfileTime(3)={''};
            tblName(3)={''};
            tblrange(3)={''};
            tblHighPass(3)={''};
            tblLowPass(3)={''};
            tblDigiFilter(3)={''};
            tblCoeff_disp(3)={''};
            tblOffset_disp(3)={''};
            tblUnit(3)={''};
            tblNo(3)={''};
        end

        Header = [tblfileID; tblfileTitle; tblfileDate; tblfileCh_num; tblfileSf;...
                        tblfileData_num; tblfileTime; tblName; tblrange; tblHighPass; tblLowPass; tblDigiFilter; tblCoeff_disp; tblOffset_disp; tblUnit; tblNo;];
    end
%--------------------------------------------------------------------------
