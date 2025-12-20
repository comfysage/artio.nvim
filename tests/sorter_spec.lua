describe("sort", function()
  local sorter = require("artio").sorter
  local lst = vim
    .iter(ipairs({ "a", "b", "c" }))
    :map(function(i, v)
      return { id = i, v = v, text = v }
    end)
    :totable()

  it("alphabet by a", function()
    assert.equals(1, vim.tbl_get(sorter(lst, "a"), 1, 1))
  end)
  it("alphabet by b", function()
    assert.equals(2, vim.tbl_get(sorter(lst, "b"), 2, 1))
  end)
  it("alphabet by c", function()
    assert.equals(3, vim.tbl_get(sorter(lst, "c"), 3, 1))
  end)
end)
