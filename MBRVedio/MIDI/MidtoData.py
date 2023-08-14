import mido
import os
import sys
# 检查文件夹是否存在
if not os.path.exists('MIDI\input.mid'):
    print("找不到输入音频input.midi|*￣ー￣|")
    sys.exit(1)
# 将MIDI文件转换为mus_freg和mus_time
def midi_to_data(midi_file):
    mus_freg = []
    mus_time = []

    mid = mido.MidiFile(midi_file)
    ticks_per_beat = mid.ticks_per_beat

    for i, track in enumerate(mid.tracks):
        tick_counter = 0
        for msg in track:
            tick_counter += msg.time
            if msg.type == 'note_on':
                if msg.velocity > 0:
                    freq = 440 * (2 ** ((msg.note - 69) / 12))
                    mus_freg.append(int(freq))
                    mus_time.append(int(tick_counter * 100 / ticks_per_beat))
                    tick_counter = 0
                else:
                    mus_freg.append(-1)
                    mus_time.append(int(tick_counter * 100 / ticks_per_beat))
                    tick_counter = 0

    return mus_freg, mus_time

# 将mus_freg和mus_time保存到文件中
def save_data_to_file(mus_freg, mus_time, output_file):
    with open(output_file, 'w') as f:
        f.write("mus_freg dw ")
        f.write(','.join([str(x) for x in mus_freg]))
        f.write("\n")
        f.write("mus_time dw ")
        f.write(','.join([str(x*100) for x in mus_time]))
        f.write("\n")

# 主函数
def main():
    midi_file = 'MIDI\input.mid'  # MIDI文件路径
    output_file = 'MIDI\data.asm'  # 输出文件路径

    mus_freg, mus_time = midi_to_data(midi_file)
    save_data_to_file(mus_freg, mus_time, output_file)

    print("转换完成，数据已保存到data.txt文件中。")

if __name__ == '__main__':
    main()
