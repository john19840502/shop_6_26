
#Spree::Product.attachment_definitions[:pdf_file][:path] = '/spree/product_pdf_files/:id/:style/:basename.:extension'

Spree::Product.class_eval do
  delegate_belongs_to :master, :price_without_tax
  after_create :generate_meta_tags

  scope :brand_search, -> (keywords) {
    joins(taxons: :taxonomy).where(['spree_taxonomies.name = ? and spree_taxons.name like ?', TAXONOMY_BRAND, "%#{keywords}%"])
  }

  scope :by_brands, -> (brands) {
    joins('INNER JOIN spree_products_taxons as spree_brands_taxons on spree_brands_taxons.product_id = spree_products.id')
        .where('spree_brands_taxons.taxon_id in (?)', brands)
  }

  def self.search_like_any(fields, values)
    where fields.map { |field|
            values.map { |value|
              if field.split('.').size == 2
                Arel::Table.new(field.split('.').first, arel_engine)[field.split('.').last]
              else
                arel_table[field]
              end.matches("%#{value}%")
            }.inject(:or)
          }.inject(:or)
  end

  def combined_properties
    props = []
    product_properties.each do |product_property|
      props << [product_property.property.presentation, product_property.value]
    end
    taxon_filter_properties.each do |taxon_filter|
      props << [taxon_filter[0],taxon_filter[1]]
    end
    measurements_properties.each do |measurement_property|
      props << measurement_property
    end
    props
  end

  def taxon_filter_properties
    taxon_filter_props = []
    grouped_by_taxonomy = taxons.group_by(&:taxonomy)
    grouped_by_taxonomy.keys.select{|m| m.is_a_filter}.each do |key|
      taxon_filter_props << [ key.name, grouped_by_taxonomy[key].collect(&:name).join(', ') ]
    end
    taxon_filter_props
  end

  def measurements_properties

    measurements_props = []
    measurements = variants.measurements

    widths = measurements.collect(&:width).uniq.compact
    measurements_props << ['Width (cm)', widths.join(', ')] unless widths.empty?

    heights = measurements.collect(&:height).uniq.compact
    measurements_props << ['Height (cm)', heights.join(', ')] unless heights.empty?

    weights = measurements.collect(&:weight).uniq.compact
    measurements_props << ['Weight (g)', weights.join(', ')] unless weights.empty?

    repeats = measurements.collect(&:repeat).uniq.compact
    measurements_props << ['Repeat (cm)', repeats.join(',')] unless repeats.empty?

    measurements_props
  end

  def generate_meta_tags
    # Set meta keywords value
    meta_keywords = []
    meta_keywords << self.name
    meta_keywords << self.brand.try(:name)
    meta_keywords << self.taxons.map(&:name)
    meta_keywords = meta_keywords.flatten
    self.meta_keywords = meta_keywords.join(",")

    # Set meta description value
    meta_description = []
    meta_description << "#{self.brand.try(:name)} online shop #{self.name} #{self.tax_category.name}"
    taxons_name = self.taxons.map(&:name)
    taxons_name[taxons_name.index(taxons_name.last)] = "#{taxons_name.last} - worldwide shipping" if taxons_name.present?
    meta_description << taxons_name
    self.meta_description = meta_description.flatten.join(",")
    self.save!
  end
end
