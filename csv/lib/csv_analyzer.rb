# This program takes a comma separated values file, or set of files,
# and parses it to analyze its contents.
#
# Author:: Tim Morgan (mailto:tmorgan@manifestcorp.com)
require 'csv'

# This class provides methods necessary to parse throgh and analyze 
# comma separated values files.
class CSVAnalyzer
  
  HEADER_ROW = 0
  
  attr_reader :csv_data, :csv_output
  attr_accessor :ignored_column_count, :data_columns

  def initialize
    @csv_data = []
    @csv_output = []
    @ignored_column_count = 0
    @data_columns = 0
  end
  
  # regex param matches columns we ARE evaluating.
  def count_columns(regex, row=self.get_header_row)
    data_col_count = 0
    row.each { |col| data_col_count += 1 if col =~ regex }
    data_col_count
  end

  # Add csv file contents from a directory to @csv_data, 
  # dir_name is relative to csv root folder by default.
  def add_to_csv_data_from_dir(dir_name)
    Dir.glob("#{dir_name}/*.csv") do |csv_file|
      @csv_data += CSV.read(csv_file)
    end
  end

  # Get the header row from a csv data array.
  def get_header_row(csv_data_array=@csv_data)
    csv_data_array.first
  end

  def set_output_header(header, overwrite=false)
    if overwrite
      @csv_output[HEADER_ROW] = header
    else
      @csv_output.insert(0, header)
    end
  end

  def parse_csv_data(header, search_term, precision)
    @csv_data.each do |row|
      matches = 0.0
      unless row == header
        row[@ignored_column_count..-1].each { |col| matches += 1 if col == search_term }
      end
      @csv_output << row if (matches / @data_columns) >= precision
    end
  end

  # Write @csv_output to a file, overwrites any existing file
  # with the same name.
  def export_csv(file_name)
    CSV.open(file_name, "wb", {:force_quotes => false}) do |csv|
      @csv_output.each { |row| csv << row }
    end
  end

end

