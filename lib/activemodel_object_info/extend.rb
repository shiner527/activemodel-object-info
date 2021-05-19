# frozen_string_literal: true

# 加载扩展
::Dir.glob('extends/**/*.rb').sort.each do |filename|
  require_relative filename
end
