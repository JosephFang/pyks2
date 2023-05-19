#!/usr/bin/env python3
# -*- coding: utf-8 -*-
##########################################################################
# libks2: A python module for accessing Kyowa KS2 file for EDX-2000A     #
# Copyright (C) 2018 ZC. Fang (zhichaofang@sjtu.org)                     #
#                                                                        #
# This program is free software: you can redistribute it and/or modify   #
# it under the terms of the GNU General Public License as published by   #
# the Free Software Foundation, either version 3 of the License, or      #
# (at your option) any later version.                                    #
#                                                                        #
# This program is distributed in the hope that it will be useful,        #
# but WITHOUT ANY WARRANTY; without even the implied warranty of         #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the          #
# GNU General Public License for more details.                           #
#                                                                        #
# You should have received a copy of the GNU General Public License      #
# along with this program.  If not, see <http://www.gnu.org/licenses/>.  #
##########################################################################

import os
import struct
import numpy as np
import scipy.io as spio
import datetime
import pandas as pd


class KS2:
    "Kyowa KS2 File Format for EDX-2000A"
    headSeek = 256  # 固定長ヘッダ部の大きさ
    infoSeek = 6
    fixCH = 16

    delta = 0

    name = None      # channel name
    chN = 0          # channel no
    unit = None      # unit
    chRange = None   # value range
    chLPF = None     # low pass
    chHPF = None     # high pass
    datetime = None  # date
    sampN = 0        # number of samples pre ch
    chMode = None    # channel mode

    raw = None       # raw data (int16)
    data = None      # measured data

    # dict for read type
    rdtpDict = {0: np.int8, 1: np.int16, 2: np.int32, 3: np.float32,
                4: np.float64, 5: np.uint8, 6: np.uint16, 7: np.uint32,
                8: np.int64, 9: np.uint64}

    def __init__(self, filename, blockno=1):
        self.filename = filename
        self.blockno = blockno

        self.fid = open(self.filename, 'br')
        self.getInfo()
        self.read()

    def getInfo(self):
        for i in range(16):
            line = self.fid.readline().replace(b'"', b'').rstrip()
            if i == 0:
                self.dev = line.decode("utf-8")
            elif i == 2:
                self.name = line.decode("utf-8")
            elif i == 3:
                self.chN = int(line)
            elif i == 4:
                self.chNcan = int(line) - self.chN
            elif i == 5:
                self.fs = int(line)
            elif i == 9:
                self.blockN = int(line)
            elif i == 12:
                self.variableHeader = int(line)
            elif i == 13:
                self.dataHeader = int(line)

    def checkFlag(self, delta):
        self.fid.seek(self.headSeek + delta)
        tmp = self.fid.read(2)
        if tmp != b'':
            [parent, child] = struct.unpack('BB', tmp)
        else:
            parent, child = 0, 0
        return parent, child

    def checkFlgNBytes(self, parent, child):
        flgNBytes = 2
        if parent == 1:
            if child in [62, 70]:
                flgNBytes = 4
        elif parent == 16:
            if child == 35:  # MAX/MIN前後400データ(KS2)
                flgNBytes = 4

        elif parent == 17:
            if child == 1:  # データ部(ks1)
                flgNBytes = 4
            elif child == 2:  # データ部(KS2)
                flgNBytes = 8

        elif parent == 18:
            if child == 25:  # REC/PAUSE時間(KS2)
                flgNBytes = 8
            elif child in [31, 32]:
                flgNBytes = 2
            else:
                flgNBytes = 4

        return flgNBytes

    def getNBytes(self, parent, child):
        flgNBytes = self.checkFlgNBytes(parent, child)
        if flgNBytes == 4:
            nBytes = struct.unpack('=I', self.fid.read(4))[0] - 2
        elif flgNBytes == 8:
            nBytes = struct.unpack('=Q', self.fid.read(8))[0] - 2
        else:
            nBytes = struct.unpack('=H', self.fid.read(2))[0] - 2

        if child in [61, 62, 70]:
            rdtp = struct.unpack('=h', self.fid.read(2))[0]
        elif child == 63:
            rdtp = struct.unpack('=i', self.fid.read(4))[0]
        else:
            self.fid.seek(1, 1)
            rdtp = self.rdtpDict[struct.unpack('B', self.fid.read(1))[0]]

        return nBytes, rdtp

    def getSizeOf(self, rdtp):
        if rdtp in [np.int8, np.uint8]:
            return 1
        elif rdtp in [np.int16, np.uint16]:
            return 2
        elif rdtp in [np.int32, np.uint32, np.float32]:
            return 4
        else:
            return 8

    def read(self):
        parent, child = self.checkFlag(self.delta)
        # 可变Header部分
        while parent in [1, 2]:
            nBytes, rdtp = self.getNBytes(parent, child)
            self.delta = self._read(
                nBytes, rdtp, parent, child, self.delta)
            parent, child = self.checkFlag(self.delta)
        # Data
        # Only read the first block
        flg = parent
        while flg <= parent:
            nBytes, rdtp = self.getNBytes(parent, child)
            self.delta = self._read(
                nBytes, rdtp, parent, child, self.delta)
            parent, child = self.checkFlag(self.delta)
            if flg < parent:
                flg = parent
            elif flg > 18:
                break

    def _read(self, nBytes, rdtp, parent, child, delta):
        flgNBytes = 2  # default

        if parent == 1:
            if child in [62, 70]:
                flgNBytes = 4
        elif parent == 2:
            "Read Header"
            if child == 48:  # valid channel index
                "Valid Channel Index"
                self.chIndex = np.frombuffer(self.fid.read(2 * self.chN),
                                             dtype=np.int16)
                print("Valid Channel Index:", self.chIndex)
            elif child == 3:
                "Coef A (slope)"
                self.coefA = np.frombuffer(self.fid.read(4 * self.chN),
                                           dtype=np.float32)
                print("CoeffA:", self.coefA)
            elif child == 4:
                "Coef B (offset)"
                self.coefB = np.frombuffer(self.fid.read(4 * self.chN),
                                           dtype=np.float32)
                print("CoeffB:", self.coefB)
            elif child == 5:
                "Channel Unit"
                self.unit = list(struct.unpack(self.chN * '10s',
                                               self.fid.read(10 * self.chN)))
                self.unit = [s.decode('utf-8').rstrip('\x00')
                             for s in self.unit]
                print('Ch Unit:', self.unit)
            elif child == 8:
                "Calibration Coefficient"
                self.calCoef = np.frombuffer(self.fid.read(4 * self.chN),
                                             dtype=np.float32)
                print("Calibration Coefficient:", self.calCoef)
            elif child == 12:
                "Offset"
                self.offset = np.frombuffer(self.fid.read(4 * self.chN),
                                            dtype=np.float32)
                print("Offset:", self.offset)
            elif child == 49:
                "Channel Name"
                self.chName = list(struct.unpack(self.chN * '40s',
                                                 self.fid.read(40 * self.chN)))
                self.chName = [s.decode('utf-8').rstrip('\x00')
                               for s in self.chName]
                print('Ch Name:', self.chName)
            elif child == 51:
                "Range"
                self.chRange = list(struct.unpack(self.chN * '20s',
                                                  self.fid.read(20 * self.chN)))
                self.chRange = [s.decode('utf-8').rstrip('\x00')
                                for s in self.chRange]
                print('Ch Range:', self.chRange)
            elif child == 53:
                "Low Pass Filter"
                self.chLPF = list(struct.unpack(self.chN * '20s',
                                                self.fid.read(20 * self.chN)))
                self.chLPF = [s.decode('utf-8').rstrip('\x00')
                              for s in self.chLPF]
                print('Ch Low Pass Filter Info:', self.chLPF)
            elif child == 54:
                "High Pass Filter"
                self.chHPF = list(struct.unpack(self.chN * '20s',
                                                self.fid.read(20 * self.chN)))
                self.chHPF = [s.decode('utf-8').rstrip('\x00')
                              for s in self.chHPF]
                print('Ch High Pass Filter Info:', self.chHPF)

        elif parent == 16:
            "Read Data Header"
            if child == 3:
                "Start Time (yyyymmddhhmmss)"
                self.datetime = self.fid.read(16).decode('utf-8')
                print("Start Time: ", self.datetime)
            elif child == 30:
                "Number of Samples"
                self.sampN = struct.unpack('=Q', self.fid.read(8))[0]
                print('Number of Samples:', self.sampN)
            elif child == 35:
                flgNBytes = 4

        elif parent == 17:
            "Read Data"
            print("Reading Data...", end=' ')
            flgNBytes = 4 if child == 1 else 8
            sizeof = self.getSizeOf(rdtp)
            nBytesPerSample = self.chN * sizeof
            length = nBytes / (nBytesPerSample)
            if round(length) != self.sampN:
                print("Warning: the number of samples mismatched!")

            # data size less than or equal to 512MiB
            if nBytes <= 512 * 1024 * 1024:
                self.raw = np.frombuffer(self.fid.read(nBytes), dtype=rdtp)\
                    .reshape((self.sampN, self.chN))
                print("Done.")
            # greater than 512MiB
            else:
                # n samples pre read block
                n0 = 512 * 1024 * 1024 // nBytesPerSample
                # num of WHOLE read block
                n = nBytes // (n0 * nBytesPerSample)
                # n samples in the final block (broken)
                n1 = self.sampN - n * n0
                self.raw = np.zeros((self.sampN, self.chN), dtype=rdtp)
                for i in range(n):
                    print(n - i, end=' ')
                    self.raw[i * n0:(i + 1) * n0, :] = np.frombuffer(
                        self.fid.read(n0 * nBytesPerSample), dtype=rdtp)\
                        .reshape((n0, self.chN))
                else:
                    print(0, end=' ')
                    if n1 > 0:
                        self.raw[n * n0:, :] = np.frombuffer(
                            self.fid.read(n1 * nBytesPerSample), dtype=rdtp)\
                            .reshape((n1, self.chN))
                print("Done.")

        elif parent == 18:
            flgNBytes = 8 if child == 25 else 4

        if flgNBytes == 4:
            delta = delta + self.infoSeek + 2 + nBytes
        elif flgNBytes == 8:
            delta = delta + self.infoSeek + 6 + nBytes
        else:
            delta = delta + self.infoSeek + nBytes

        return delta

    def convertData(self):
        "convert data from short to float"
        self.data = np.zeros_like(self.raw, dtype=np.float32)
        for i in range(self.chN):
            self.data[:, i] = self.coefA[i] * self.raw[:, i] + self.coefB[i]

    def savecsv(self, savename, instrument = 'edx100a'):

        if savename is not None:
            if os.path.splitext(savename)[1] == '.csv':
                
                date_time_obj = datetime.datetime.strptime(self.datetime.rstrip('\x00'), '%Y%m%d%H%M%S')
 
                if instrument == 'edx100a':
                    self.raw = self.coefA*self.raw+self.coefB
                    # ratio = 0.0003125
                    data = {
                    'idNo':self.dev,
                    'name': self.name,
                    'datetime': date_time_obj,
                    'fs': self.fs,
                    'sampN': self.sampN,
                    'chN': self.chN,
                    'chName': self.chName,
                    'chIndex': self.chIndex,
                    'range': self.chRange,
                    'coefA': self.coefA,
                    'coefB': self.coefB,
                    'calCoef': self.calCoef,
                    'meaZero': self.offset,
                    'LPFinfo': self.chLPF,
                    'HPFinfo': self.chHPF,
                    'chUnit': self.unit,
                    # 'RAW': self.raw
                                        }
                
                elif instrument == 'dcs100a':
                
                    calibrate_coef = np.array([0.0004596,0.0004766,0.0004598,0.0004778,0.0004544,0.0004787,0.0004492,0.000471,0.0004498,0.0004704,0.0004598,0.0004815,0.0002915,0.0002935,0.0002897,0.0002903,0.0002925,0.000292,0.0002928,0.0002937,0.0002928,0.0002949,0.0002911,0.0002928,0.0002893,0.0002893,0.0002931,0.0002892,0.0002909,0.0002908,0.0002929,0.0002915,0.0002927,0.0002916,0.0002901,0.0002908,1,1,1,1,1,1,1,1,1,1,1,1,1,1])
                    # list_raw = self.raw[0]
                    # list_ratio = list_ref/list_raw
                    # print(list_ratio)
                    self.raw = calibrate_coef*self.raw
                        
                    data = {
                    'idNo':self.dev,
                    'name': self.name,
                    'datetime': date_time_obj,
                    'fs': self.fs,
                    'sampN': self.sampN,
                    'chN': self.chN,
                    'chName': self.chName,
                    'chIndex': self.chIndex,
                    'range': self.chRange,
                    # 'coefA': self.coefA,
                    # 'coefB': self.coefB,
                    # 'calCoef': self.calCoef,
                    # 'meaZero': self.offset,
                    'LPFinfo': self.chLPF,
                    'HPFinfo': self.chHPF,
                    'chUnit': self.unit,
                    # 'RAW': self.raw
                                        }
                    
                for i, v in enumerate(self.raw):
                    data[i] = v
                
                df = pd.DataFrame.from_dict(dict([ (k,pd.Series(v)) for k,v in data.items() ]), orient='index')
                df = df.round(7)
                df.to_csv(savename, index=True)
                print("Saving data in csv format...")
        else:
            print("To be expected!")
        
        

    def save(self, ext=None, savename=None):
        """save data in the given format
        ext: .mat, save in matlab format
             .xlsx, save in excel format
             .txt, save in ascii format

        NOTE: saving in the latter two formats has not be implemented yet.
        """
        if savename is not None:
            if os.path.splitext(savename)[1] == '.mat':
                self._savemat(savename)
            else:
                print("To be expected!")
        elif ext is None and savename is None:
            # Default: .mat
            savename = os.path.splitext(self.filename)[0] + '.mat'
            self._savemat(savename)
        elif ext is not None and savename is None:
            if not ext.beginswith('.'):
                ext = '.' + ext
            savename = os.path.splitext(self.filename)[0] + ext
            if savename.endswith('.mat'):
                self._savemat(savename)
            else:
                print("To be expected!")
        else:
            print("To be expected!")

    def _savemat(self, savename):
        print("Saving data in mat format...")
        spio.savemat(savename, {'name': self.name,
                                'datetime': self.datetime,
                                'fs': self.fs,
                                'sampN': self.sampN,
                                'chN': self.chN,
                                'chIndex': self.chIndex,
                                'chName': self.chName,
                                'chUnit': self.unit,
                                'range': self.chRange,
                                'coefA': self.coefA,
                                'coefB': self.coefB,
                                'calCoef': self.calCoef,
                                'meaZero': self.offset,
                                'LPFinfo': self.chLPF,
                                'HPFinfo': self.chHPF,
                                'RAW': self.raw})

    def __str__(self):
        return """KS2 data object
    ({:s}, {:s}, {:s},
    N ch: {:d}, fs: {:d} Hz, N block: {:d}, N samples: {:d})""".format(
            self.dev, self.name, self.datetime, self.chN, self.fs, self.blockN,
            self.sampN)

    def __del__(self):
        self.fid.close()


if __name__ == "__main__":
    import argparse
    import pandas as pd
    import matplotlib.pyplot as plt

    print("""
A Python code to access Kyowa KS2 file.
Copyright (C) 2018 ZC. Fang (zhichaofang@sjtu.org)

This program comes with ABSOLUTELY NO WARRANTY.
This is free software, and you are welcome to redistribute it under certain conditions.
        """)

    parser = argparse.ArgumentParser()
    parser.add_argument('i', type=str, help='input ks2 file name')
    parser.add_argument('-s', '--save', dest='save', action='store_const',
                        const=True, default=False, help='export data file')
    parser.add_argument('-o', type=str, nargs='?',
                        default=None, help='export file name')
    parser.add_argument('-p', '--plot', dest='plot', action='store_const',
                        const=True, default=False, help='plot measured data')
    parser.add_argument('-c', type=int, nargs='+',
                        default=None, help='channels')

    args = parser.parse_args()

    ks2 = KS2(args.i)

    if args.save:
        ks2.save(savename=args.o)

    if args.plot:
        if args.c is None:
            args.c = range(ks2.chN)
        # down sample the data for plotting
        di = round(max(1, ks2.fs / 200))
        rawDS = ks2.raw[::di, :]
        if len(args.c) == 1:
            dataDS = np.array(list(map(
                lambda i: ks2.coefA[i] * rawDS[:, i] + ks2.coefB[i], args.c))).reshape((-1, 1))
        else:
            dataDS = np.array(
                list(map(lambda i: ks2.coefA[i] * rawDS[:, i] + ks2.coefB[i], args.c))).T

        t = np.arange(dataDS.shape[0]) / (ks2.fs / di)
        chNames = list(map(lambda i: ks2.chName[i], args.c))
        dataframe = pd.DataFrame(dataDS, index=t, columns=chNames)
        ax = dataframe.plot(linewidth=1)
        ax.set_xlabel(r'$t$ (s)')
        ax.legend(loc=1, fontsize='small')

        plt.show()
