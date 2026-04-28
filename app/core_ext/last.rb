class String
  def last(limit = 1)
    return '' if limit == 0
    self[-limit, limit] || self
  end
end
