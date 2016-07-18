#!/usr/local/bin/ruby23
# coding: utf-8

require 'png'

def usage
  print "usage: ruby mag2png.rb mag_file_name.mag\n"
  exit 1
end

def main
  usage unless ARGV[0]
  ld = Loader.new ARGV[0]
  canvas = ld.load
  png = PNG.new canvas
  png.save "hoge.png"
end

class Loader
  class FlagA
    def initialize buf, ofs
      @buf = buf
      @offset = ofs - 1
      @bitpos = 1
    end

    def read
      if (@bitpos >>= 1) == 0 then
        @bitpos = 128
        @offset += 1
      end
      return (@buf[@offset].ord & @bitpos) != 0
    end
  end

  class FlagB
    def initialize buf, ofs
      @buf = buf
      @offset = ofs - 1
    end

    def read
      @offset += 1
      tmp = @buf[@offset].ord
      return ((tmp >> 4) & 15), (tmp & 15)
    end
  end

  class Pix
    def initialize buf, ofs
      @buf = buf
      @offset = ofs - 1
    end

    def read
      @offset += 1
      return @buf[@offset].ord & 255
      if @buf[@offset] then
        return @buf[@offset].ord & 255
      else
        return 255
      end
    end
  end

  def initialize pathname
    open(pathname, 'rb:ASCII-8BIT'){|file|
      sig = file.read 8
      raise "signature error" if sig != 'MAKI02  '
      comment = ""
      c = nil
      loop {
        c = file.read 1
        break if c == "\x1a"
        comment << c
      }
      comment.force_encoding Encoding::WINDOWS_31J
      #print "\"#{comment.encode Encoding::UTF_8}\"\n"
      @buf = file.read
    }
  end

  def load
    # parse header
    # tl=TopLeft br=BottomRight
    _, machine_code, machine_flag, screen_mode, tl_x, tl_y, br_x, br_y, flg_a_ofs, flg_b_ofs, flg_b_sz, pix_ofs, pix_sz = @buf.unpack 'C4v4V5'
    flg_a = FlagA.new @buf, flg_a_ofs
    flg_b = FlagB.new @buf, flg_b_ofs
    pix = Pix.new @buf, pix_ofs
    colors = 16
    colors = 8 if (screen_mode & 2) != 0
    colors = 256 if (screen_mode & 128) != 0
    palet = []
    (0 ... colors).each {|i|
      g, r, b = @buf[32 + i*3, 3].unpack('C3')
      palet << PNG::Color.new(r, g, b)
    }
    #p palet
    pix_width = if colors == 256 then 2 else 4 end
    pix_width2 = pix_width * 2
    width = ((br_x / pix_width2 - tl_y / pix_width2) + 1) * pix_width2
    height = br_y + 1 - tl_y
    #p [width, height]
    canvas = PNG::Canvas.new width, height
    flg_b_buf = Array.new(width / pix_width, 0)
    tbl = [nil, [-1, 0], [-2, 0], [-4, 0],
           [0, -1], [-1, -1],
           [0, -2], [-1, -2], [-2, -2],
           [0, -4], [-1, -4], [-2, -4],
           [0, -8], [-1, -8], [-2, -8], [0, -16]]
    (0 ... height).each {|y|
      (0 ... (width/pix_width2)).each {|i|
        if flg_a.read then
          r, l = flg_b.read
          flg_b_buf[i*2]   ^= r
          flg_b_buf[i*2+1] ^= l
        end

        # right pixel
        ref_pos = tbl[flg_b_buf[i*2]]
        pixel = []
        if ref_pos then
          x = i * pix_width2
          xdiff = ref_pos[0] * pix_width
          ry = height-1-y-ref_pos[1]
          (0 ... pix_width).each {
            rx = x + xdiff
            pixel << canvas[rx, ry]
            x += 1
          }
        else
          tmp1 = pix.read
          tmp2 = pix.read
          case pix_width
          when 2 then
            pixel << palet[tmp1]
            pixel << palet[tmp2]
          when 4 then
            pixel << palet[(tmp1>>4) & 15]
            pixel << palet[tmp1 & 15]
            pixel << palet[(tmp2>>4) & 15]
            pixel << palet[tmp2 & 15]
          else
            raise
          end
        end
        x = i * pix_width2
        pixel.each {|color|
          canvas[x, height-1-y] = color
          x += 1
        }

        # left pixel
        ref_pos = tbl[flg_b_buf[i*2+1]]
        pixel = []
        if ref_pos then
          x = i * pix_width2 + pix_width
          xdiff = ref_pos[0] * pix_width
          ry = height-1-y-ref_pos[1]
          (0 ... pix_width).each {
            rx = x + xdiff
            pixel << canvas[rx, ry]
            x += 1
          }
        else
          tmp1 = pix.read
          tmp2 = pix.read
          case pix_width
          when 2 then
            pixel << palet[tmp1]
            pixel << palet[tmp2]
          when 4 then
            pixel << palet[(tmp1>>4) & 15]
            pixel << palet[tmp1 & 15]
            pixel << palet[(tmp2>>4) & 15]
            pixel << palet[tmp2 & 15]
          else
            raise
          end
        end
        x = i * pix_width2 + pix_width
        pixel.each {|color|
          canvas[x, height-1-y] = color
          x += 1
        }
      }
    }
    return canvas
  end
end

def fill_it canvas, w, h
  (0 ... h).each {|y|
    (0 ... w).each {|x|
      r = 255 * x / 320
      if r > 255 then
        r = 255
      end

      g = 255 * y / 400
      if g > 255 then
        g = 255
      end

      b = 255 * (639 - x) / 320
      if b > 255 then
        b = 255
      end

      col = PNG::Color.new r, g, b
      canvas[x, y] = col
    }
  }
end

main
