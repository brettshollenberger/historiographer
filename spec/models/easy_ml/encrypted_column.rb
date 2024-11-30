module EasyML
  class EncryptedColumn < Column
    include Historiographer

    def encrypted?
      true
    end
  end
end