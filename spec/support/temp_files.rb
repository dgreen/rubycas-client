module TempFiles
  def self.included(example_group)
    example_group.extend(self)
  end

  def create_temp_file(file)
    before(:each) do
      @tmp_dir = SPEC_TMP_DIR
      @file_path = File.join(@tmp_dir, file)
      FileUtils.touch(@file_path)
    end

    define_method(:content_for_file) do |content|
      f = File.new(@file_path, 'a+')
      f.write(content)
      f.flush # VERY IMPORTANT
      f.close
    end

    define_method(:file_path) do
      @file_path
    end
  end
end
