class ReplaceDANTEURIBaseConfig extends BaseConfigPlugin
  getFieldDefFromParm: (baseConfig, pname, def, parent_def) ->
    
    if def.plugin_type != "replace-dante-uri-form"
      return 
    
    # generate form with datatable
    replaceForm =
      type: CUI.Form
      name: "replace_dante_uri"
      class: "replace_dante_uri"
      fields: [
        type: CUI.DataTable
        rowMove: true
        name: "data_table"
        fields: [
          form:
            label: $$("replacedanteuriform.data_table.from_dante_uri")
          type: CUI.Input
          name: "from"
        ,
          form:
            label: $$("replacedanteuriform.data_table.to_dante_uri")
          type: CUI.Input
          name: "to"        
        ]
      ]

    replaceForm

CUI.ready =>
  BaseConfig.registerPlugin(new ReplaceDANTEURIBaseConfig())