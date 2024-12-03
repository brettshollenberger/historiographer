module EasyML
  class EncryptedColumn < Column
    self.inheritance_column = "column_type"
    include Historiographer

    def encrypted?
      true
    end
  end
end