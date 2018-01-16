# **pyks2**

A python module to access the Kyowa KS2 binary file

By ZC. Fang
Copyright &copy; 2018

## 功能

+ 读取KS2文件

    数据采用int16存储，转化公式：`data = coefA * raw + coefB`

+ 转存至.mat

    仍然采用int16存储

+ 基本的绘图功能（对高速采集信号进行下采样后绘出）

+ TODO:
  + 增加导出excel, txt等功能

## 依赖环境

+ Python >= 3.4
+ Numpy >= 1.13
+ Scipy >= 0.19
+ Pandas >=

## KS2版本要求

+ *ks2 version*: 01.00
+ *csv version*: 0 (old)
+ **No** CAN channel
+ **No** digital channel

## 使用

见run.ipynb

## Appendix: Parent ID and Child ID

### 可変長ヘッダ部全体情報 (`parent id == 1`)

child id

* 4:
* 44
* 45
* 46: Item name
* 47:
* 54
* 55
* 56
* 57
* 58
* 59
* 60
* 61: CAN-ID Info, flgNBytes = 2,
* 62: CAN-CH Condition, flgNBytes = 4
* 63: CAN通信条件, flgNBytes = 2
* 70: CAN-CH条件, flgNBytes = 4

### 可変長ヘッダ部個別情報 (`parent id == 2`)

child id

* 2 || 48: valid channel id (2: ks1, 48: ks2), flgCoeff = 3
* 3: coef A, flgCoeff = 1, (KS2 ver01.01~03, float)
* 4: coef B, flgCoeff = 2, (KS2 ver01.01~03, float)
* 67: coef A, flgCoeff = 1, (KS2 ver01.04, double)
* 68: coef B, flgCoeff = 2, (KS2 ver01.04, double)
* 5: unit, flgCoeff = 5;
* 6:
* 8: calibration coefficient, flgCoeff = 7
* 12: offset, flgCoeff = 8
* 48
* 49: channel name, flgCoeff = 4
* 50
* 51: range, flgCoeff = 6
* 52
* 53: low pass filter, flgCoeff = 9
* 54: high pass filter, flgCoeff = 10
* 55

### Data Head (`parent id == 16`)

child id

- 3: start time, flgCoeff = 9
- 29
- 30: number of samples, flgCoeff = 10
- 31:
- 32
- 33
- 34: max/min data, flgNBytes = 2 (for ks2ver < 5)
- 35: 400 data samples before and after max/min data, flgNBytes = 4
- 36: time point when the max/min data occur

### Data (`parent id == 17`)

child id

- 1: flgNBytes = 4 (ks1)
- 2 (and else): flgNBytes = 8 (ks2)

### PostData (`parent id == 18`)

child id

- 25: flgNBytes = 8
- 26 (and else): flgNBytes = 4
