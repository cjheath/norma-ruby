require 'ruby-debug'
Debugger.start

require 'nokogiri'
require 'activefacts/api'

module NORMA
  class XML

    def initialize(filename)
      @filename = filename
    end

    def read
      File.open(@filename) do |file|
	@document = Nokogiri::XML(file)
      end
      puts "Successfully read #{@filename}"
    rescue => e
      puts "Failed to parse XML in #{@filename}: #{e.inspect}"
    end

    def index
      root = @document.root

      raise "Not a valid ormRoot::ORM2 file" unless root.name == "ORM2" && root.namespace.prefix == "ormRoot"

      # Index all objects by their id:
      @ids = {}
      @ids = root.xpath('.//*[@id]').each do |x|
	  @ids[x['id']] = x
	end

      # Index all objects that refer to an object by an id:
      @references = Hash.new{|h, k| h[k] = []}
      root.xpath('.//*[@ref]').each do |x|
	  ref = x['ref']
	  @references[ref] << x
	end

      @x_models = root.xpath('orm:ORMModel')
      @x_groupings = root.xpath('orm:Grouping')
      @x_diagrams = root.xpath('ormDiagram:ORMDiagram')

      puts "Indexed, with #{@x_models.size} models, #{@x_groupings.size} groupings and #{@x_diagrams.size} diagrams"
    end

    def convert
      constellation = ActiveFacts::API::Constellation.new(NORMA)
      @models = @x_models.
	map do |x_model|
	  model_id = x_model['id'] 
	  x_groupings = @x_groupings.map do |x_grouping|
	    model_ref = x_grouping.xpath('orm:ORMModel')[0]['ref']
	    if model_id == model_ref
	      x_grouping
	    else
	      nil
	    end
	  end.compact

	  model_name = x_model['Name'] 
	  model = constellation.Model(model_name)
	  model.convert_model x_model, x_groupings
	end
      constellation
    end
  end

  class Name < String
    value_type
  end

  class ReferenceMode < String
    value_type
  end

  class Guid < ::Guid
    value_type
  end

  class ObjectType
    identified_by :model, :name
    has_one :model, :mandatory => true
    has_one :name, :mandatory => true
    one_to_one :guid
    maybe :is_independent
    maybe :is_personal
    has_one :_reference_mode
  end

  class DataType < ObjectType
  end

  class EntityType < ObjectType
    has_one :nested_predicate, :class => "FactType"
  end

  class Scale < SignedInteger
    value_type :length => 32
  end

  class Length < SignedInteger
    value_type :length => 32
  end

  class ValueType < ObjectType
    maybe :is_implicit_boolean_value
    has_one :data_type
    has_one :length
    has_one :scale
  end

  class Role
    identified_by :guid
    one_to_one :guid, :mandatory => true
    has_one :fact_type, :mandatory => true
    has_one :player, :class => ObjectType, :mandatory => true
  end

  class FactType
    identified_by :guid
    one_to_one :guid, :mandatory => true
    has_one :model, :mandatory => true
    has_one :_name, :class => Name, :mandatory => true
  end

  class SubtypeFactType < FactType
    maybe :is_preferred_identification_path
    has_one :subtype_meta_role, :class => 'Role'
    has_one :supertype_meta_role, :class => 'Role'
  end

  class Constraint
    identified_by :guid
    one_to_one :guid, :mandatory => true
    has_one :model, :mandatory => true
    has_one :name, :mandatory => true
    maybe :is_deontic
  end

  class Value < String
    value_type
  end

  class ValueRange
    identified_by :min_value, :max_value, :includes_min, :includes_max, :value_constraint
    has_one :min_value, :class => Value
    has_one :max_value, :class => Value
    maybe :includes_min
    maybe :includes_max
    has_one :value_constraint
  end

  class ValueConstraint < Constraint
  end

  class Function
    identified_by :guid
    one_to_one :guid, :mandatory => true
    has_one :model, :mandatory => true
    has_one :name, :mandatory => true
  end

  class ModelNote
    identified_by :guid
    one_to_one :guid, :mandatory => true
    has_one :model, :mandatory => true
  end

  class CustomReferenceMode
    identified_by :guid
    one_to_one :guid, :mandatory => true
    has_one :model, :mandatory => true
    has_one :name, :mandatory => true
    has_one :reference_mode_kind
  end

  class ReferenceModeKind
    identified_by :guid
    one_to_one :guid, :mandatory => true
    has_one :model, :mandatory => true
    has_one :name, :mandatory => true
  end

  class Model
    identified_by :name
    one_to_one :name, :mandatory => true
    one_to_one :guid

    def convert_model x_model, x_groupings
      @x_model = x_model
      @x_groupings = x_groupings
      @x_groups = x_groupings.map{|g| g.xpath('orm:Groups/orm:Group') }.flatten

      @name = @x_model['Name']

      convert_entity_types
      convert_data_types
      convert_value_types
      convert_fact_types
      convert_objectifications
      convert_roles
      convert_subtyping
      convert_constraints

      puts "Constructed model #{@name} with #{@x_groupings.size} groupings having #{@x_groups.size} groups"
    end

    def convert_entity_type x_entity_type
      id = x_entity_type['id']
      name = (x_entity_type['Name'] || "")
      # name = name.gsub(/\s+/,' ').gsub(/-/,'_').strip
      et = @constellation.EntityType(:model => self, :name => name, :guid => clean_id(id))

      independent = x_entity_type['IsIndependent']
      et.is_independent = independent == 'true'
      personal = x_entity_type['IsPersonal']
      et.is_personal = 'personal' if personal && personal == 'true'
      et._reference_mode = x_entity_type['_ReferenceMode']
      et
    end

    def convert_entity_types
      @x_model.xpath('orm:Objects/orm:EntityType').each do |x_entity_type|
	convert_entity_type x_entity_type
      end
      puts "Converted #{@constellation.EntityType.size} entity types"
    end

    def convert_data_type x_data_type
      name = x_data_type.name
      guid = clean_id(x_data_type['id'])
      @constellation.DataType(:model => self, :name => name, :guid => guid)
    end

    def convert_data_types
      @x_model.xpath('orm:DataTypes/*').each do |x_data_type|
	convert_data_type x_data_type
      end
      puts "Converted #{@constellation.DataType.size} data types"
    end

    def convert_value_type x_value_type
      id = x_value_type['id']
      name = (x_value_type['Name'] || "")
      # name = name.gsub(/\s+/,' ').gsub(/-/,'_').strip
      vt = @constellation.ValueType(:model => self, :name => name)
      vt.guid = clean_id(id)

      independent = x_value_type['IsIndependent']
      vt.is_independent = independent == 'true'
      personal = x_value_type['IsPersonal']
      vt.is_personal = 'personal' if personal == 'true'

      is_implicit_boolean_value = x_value_type['IsImplicitBooleanValueP']
      vt.is_implicit_boolean_value = is_implicit_boolean_value == 'true'

      x_data_type = x_value_type.xpath('orm:ConceptualDataType')[0]
      data_type_guid = clean_id(x_data_type['ref'])
      guid = @constellation.Guid[::Guid.new(data_type_guid)]
      data_type = guid.object_type
      raise "No data type for #{data_type_guid} in value type #{vt.name}" unless data_type.kind_of?(DataType)
      vt.data_type = data_type

      if scale = x_data_type['Scale']
	vt.scale = scale.to_i
      end
      if length = x_data_type['Length']
	vt.length = length.to_i
      end

      vt
    end

    def convert_value_types
      @x_model.xpath('orm:Objects/orm:ValueType').each do |x_value_type|
	convert_value_type x_value_type
      end
      puts "Converted #{@constellation.ValueType.size} value types"
    end

    def convert_fact_type x_fact_type
      id = x_fact_type['id']
      name = x_fact_type['Name'] || x_fact_type['_Name'] || ''

      ft = @constellation.FactType(:guid => clean_id(id))
      ft.model = self
      ft._name = name

      # Note that the new metamodel doesn't have a name for a facttype unless it's objectified
      # next if x_fact_type.xpath('orm:DerivationRule').size > 0
    end

    def convert_fact_types
      @x_model.xpath('orm:Facts/orm:Fact').each do |x_fact_type|
	convert_fact_type x_fact_type
      end
      puts "Converted #{@constellation.FactType.size} fact types"
    end

    def convert_objectification x_objectification
      et = convert_entity_type x_objectification
      fact_type_guid = clean_id(x_objectification.xpath('orm:NestedPredicate')[0]['ref'])
      fact_type = @constellation.FactType[[::Guid.new(fact_type_guid)]]
      raise "No fact for #{fact_type_guid} in objectification #{et.name}" unless fact_type
      et.nested_predicate = fact_type
    end

    def convert_objectifications
      count = 0
      @x_model.xpath('orm:Objects/orm:ObjectifiedType').each do |x_objectification|
	convert_objectification x_objectification
	count += 1
      end
      puts "Converted #{count} objectifications"
    end

    def convert_role x_role
      fact_type_guid = clean_id(x_role.parent.parent['id'])
      fact_type = @constellation.FactType[[::Guid.new(fact_type_guid)]]
      raise "No fact for #{fact_type_guid}" unless fact_type

      x_role_player = x_role.xpath('orm:RolePlayer')[0]
      player_guid = clean_id(x_role_player['ref'])
      g = @constellation.Guid[::Guid.new(player_guid)]
      player = g && g.object_type
      raise "No role player for guid #{player_guid}" unless player

      id = x_role['id']
      name = x_role['Name']
      # x_role['_IsMandatory']
      # x_role['_Multiplicity']

      role = @constellation.Role(:guid => clean_id(id))
      role.fact_type = fact_type
      role.player = player
      role
    end

    def convert_roles
      @x_model.xpath('orm:Facts/orm:Fact/orm:FactRoles/orm:Role').each do |x_role|
	convert_role x_role
      end
      puts "Converted #{@constellation.Role.size} roles"
    end

    def convert_subtype x_subtype
      id = x_subtype['id']
      name = x_subtype['_Name'] || ''

      ft = @constellation.SubtypeFactType(:guid => clean_id(id))
      ft.model = self
      ft._name = name
      ft.is_preferred_identification_path = x_subtype['PreferredIdentificationPath'] == 'true'

      ft.subtype_meta_role = convert_role x_subtype.xpath('orm:FactRoles/orm:SubtypeMetaRole')[0]
      ft.supertype_meta_role = convert_role x_subtype.xpath('orm:FactRoles/orm:SupertypeMetaRole')[0]
      ft
    end

    def convert_subtyping
      roles_before = @constellation.Role.size
      @x_model.xpath('orm:Facts/orm:SubtypeFact').each do |x_subtype|
	convert_subtype x_subtype
      end
      puts "Converted #{@constellation.SubtypeFactType.size} subtyping fact types"
    end

    def convert_value_constraint x_value_restriction
      x_constrained = x_value_restriction.parent
      guid = @constellation.Guid[::Guid.new(clean_id(x_constrained['id']))]
      constrained = guid.role || guid.object_type
      raise "Value constraint target #{guid} not found" unless constrained

      x_vcs = x_value_restriction.xpath(constrained.kind_of?(Role) ? 'orm:RoleValueConstraint' : 'orm:ValueConstraint')
      name = x_vcs[0]['Name']

      vc = @constellation.ValueConstraint(:guid => guid)
      vc.model = self
      vc.name = name

      # Here, * is normally an orm:ValueConstraint, but in derivations it will be orm:PathedRoleConditionValueConstraint
      x_value_restriction.xpath('*/orm:ValueRanges/orm:ValueRange').each do |x_value_range|
	min_value = x_value_range['MinValue']
	min_value = nil if min_value == ''
	max_value = x_value_range['MaxValue']
	max_value = nil if max_value == ''
	includes_min = x_value_range['MinInclusion'] != 'NotSet'
	includes_max = x_value_range['MaxInclusion'] != 'NotSet'
	@constellation.ValueRange(:value_constraint => vc, :min_value => min_value, :max_value => max_value, :includes_min => includes_min, :includes_max => includes_max)
      end
    end

    def convert_value_constraints
      (@x_model.xpath('orm:Facts/orm:Fact/orm:FactRoles/orm:Role/orm:ValueRestriction') +
       @x_model.xpath('orm:Objects/orm:ValueType/orm:ValueRestriction')
      ).each do |x_value_restriction|
	convert_value_constraint x_value_restriction
      end
      puts "Converted #{@constellation.ValueConstraint.size} value constraints with #{@constellation.ValueRange.size} ranges"
    end

    def convert_constraints
      convert_value_constraints

      # REVISIT: Remaining constraint types
    end

    def clean_id id
      id.sub(/^_/,'')
    end
  end
end

if __FILE__ == $0
norma = NORMA::XML.new(ARGV[0])
norma.read
norma.index
norma.convert
end
