#!/usr/bin/env ruby

require 'fileutils'

pdf_file_name = ARGV.shift

abort 'Usage: `pdf-image-scraper.rb <pdf_file>`' if pdf_file_name.to_s.empty?

output = `pdfimages -all -list #{pdf_file_name}`

lines = output.split("\n")
lines.map!{|l| l.split(/\s+/)}

# get image numbers with masks
images = {}
lines.each_with_index do |l,i|
    puts l.inspect
    if l[3] =~ /image/
        image_number = l[2].to_i
        extension = l[9].eql?("image") ? "png" : "jpg"
        images[image_number] = {filename: "image-#{image_number.to_s.rjust(3, "0")}.#{extension}"}
        if lines[i+1][3] =~ /smask/
            mask_number = lines[i+1][2].to_i
            mask_extension = lines[i+1][9].eql?("image") ? "png" : "jpg"
            images[image_number].merge!({mask: "image-#{mask_number.to_s.rjust(3, "0")}.#{mask_extension}"})
        end
    end
end

# perform image conversion
`pdfimages -all #{pdf_file_name} image`

# combine files with masks
images.each_pair do |num, info|
    if info.has_key?(:mask)
        `convert #{info[:filename]} #{info[:mask]} -compose CopyOpacity -composite -trim unified-#{num}.png`
        File.delete(info[:filename])
        File.delete(info[:mask])
    end
    #puts num, info
end

images = Dir.glob("*.jpg") + Dir.glob("*.png")
image_hashes = {}

images.each do |filename|
    image_hash = `identify -verbose #{filename} | grep signature`.split(':').last.strip
    if image_hashes.has_key?(image_hash)
        # prune duplicate images
        File.delete(filename)
    else
        image_hashes[image_hash] = filename
    end
end

Dir.mkdir('output') unless Dir.exists?('output')
FileUtils.mv Dir.glob('{image,unified}*.{jpg,png}'), 'output/'
