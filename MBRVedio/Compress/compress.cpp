#include <iostream>
#include <fstream>
#include <vector>

#define BLOCK_SIZE 32768 // ��鴦��Ŀ��С
#define LMIN 4 // ��Сƥ�䳤��
#define LMAX 255 // ���ƥ�䳤��

void compressBlock(const std::vector<unsigned char>& block, std::ofstream& outfile) {
    std::vector<unsigned char> bytes(block.size());
    int bi = 0;
    int pos = 0;

    while (pos < block.size()) {
        unsigned char l = 0, ml = 0; // ��ǰƥ�䳤�ȡ����ƥ�䳤��
        short p = 0, mp = 0; // ��ǰƥ��λ�á����ƥ��λ��

        // �ڵ�ǰλ��֮ǰ�������ƥ��
        for (; p < pos; p++) {
            if (l >= LMAX)
                break;

            if (block[p] == block[pos + l]) {
                l++;
            } else {
                if (l >= ml) {
                    ml = l;
                    mp = p;
                }

                p -= l;
                l = 0;
            }
        }

        if (l >= ml) {
            ml = l;
            mp = p;
        }

        if (ml >= LMIN) {
            int bs = 0;
            while (bi > 0) {
                int bx = bi;
                if (bx > 128) bx = 128;

                unsigned char b = (1 << 7) | (bx - 1); // ����ֽ�

                outfile.write(reinterpret_cast<char*>(&b), 1);
                outfile.write(reinterpret_cast<char*>(bytes.data() + bs), bx);

                bi -= bx;
                bs += bx;
            }

            mp = (mp - ml);
            mp = (mp >> 8) | (mp << 8); // ��С�˸�ʽд�����ƥ��λ��
            outfile.write(reinterpret_cast<char*>(&mp), 2);
            outfile.write(reinterpret_cast<char*>(&ml), 1); // д�����ƥ�䳤��

            pos += ml;
        } else {
            bytes[bi++] = block[pos++];
        }
    }

    int bs = 0;
    while (bi > 0) {
        int bx = bi;
        if (bx > 128) bx = 128;

        char b = (1 << 7) | (bx - 1);
        outfile.write(&b, 1);
        outfile.write(reinterpret_cast<char*>(bytes.data() + bs), bx);

        bi -= 128;
        bs += 128;
    }
}

int main(int argc, char **argv) {
    if (argc != 3) {
        std::cerr << "����Ĵ��Σ���ȷ���Σ� [�����ļ�] [����ļ�]" << std::endl;
        return 1;
    }

    std::ifstream infile(argv[1], std::ios::binary);
    if (!infile) {
        std::cerr << "�޷��������ļ����ж�ȡ��" << std::endl;
        return 2;
    }

    std::ofstream outfile(argv[2], std::ios::binary);
    if (!outfile) {
        std::cerr << "�޷�������ļ�����д�롣" << std::endl;
        return 2;
    }

    std::vector<unsigned char> block(BLOCK_SIZE);
    while (!infile.eof()) {
        infile.read(reinterpret_cast<char*>(block.data()), BLOCK_SIZE);
        std::streamsize bytesRead = infile.gcount();

        if (bytesRead > 0) {
            block.resize(bytesRead);
            compressBlock(block, outfile);
        }
    }

    infile.close();
    outfile.close();
    
    return 0;
}

