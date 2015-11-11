module TenantSpitter
  class Service
    attr_reader :buckets, :klass_map, :options

    def initialize(options = {})
      @options = options
    end

    def prepare
      @buckets = { initiate_class => initiate_relation.pluck(:id) }
      @klass_map = { initiate_class => [] }
      scan_ids(initiate_class)
    end

    def dump(stream = STDOUT, debug = false)
      klass_map.each do |klass, subclasses|
        klasses = [klass] + subclasses
        ids = klasses.map {|k| Array(@buckets[k]) }.reduce(:|)

        klass.where(id: ids).limit(10).each do |r|
          im = klass.arel_table.create_insert
          im.insert(r.send(:arel_attributes_with_values_for_create, r.attribute_names))
          stream.write("#{im.to_sql};\n")
        end
      end

      puts "Finished"
      true
    end

    def scan_ids(current_klass, deep = 0)
      s =  "-" * deep
      puts "#{s}#{current_klass.name}"
      begin
        parent_ids = @buckets[current_klass]
        return if parent_ids.empty?

        current_klass.reflect_on_all_associations(:has_many).each do |reflection|

          next if skip?(reflection.class_name)
          next unless defined?(reflection.klass)

          klass = reflection.klass
          base_class = klass.base_class
          options = reflection.options

          @klass_map[base_class] ||= []
          @klass_map[base_class] << klass if klass != base_class

          next if options[:through]
          # next if @buckets.key?(klass) && klass == base_class
          deeply_visited = @buckets.key?(klass) && klass == base_class

          foreign_key = reflection.foreign_key
          ids = klass.where(foreign_key => parent_ids).pluck(:id)

          # @buckets[klass] = (Array(@buckets[klass]) | ids)
          @buckets[klass] = (Array(@buckets[klass]) | ids)
          # @buckets[klass] = ids

          scan_ids(klass, deep+1) unless deeply_visited
        end
      rescue => e
        puts current_klass
        raise e
      end
    end

    private

    def skip?(class_name)
      return true if skipped_class_names.include?(class_name)
      class_name =~ /Archive/
    end

    def skipped_class_names
      ['IbSubject','InternalAssignment']
    end

    def initiate_relation
      initiate_class.where(initiate_scope_condition)
    end

    def initiate_scope_condition
      # { subdomain: ['faria'] }
      # options[:initiate_condition]
      parse_initiate_condition
    end

    def initiate_class
      options[:initiate_class].constantize
    end

    def parse_initiate_condition
      key, values = *options[:initiate_condition].split("=")
      { key => values.split(',') }
    end
  end
end