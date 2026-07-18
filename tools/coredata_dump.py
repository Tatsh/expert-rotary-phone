#!/usr/bin/env python3
"""Convert compiled Core Data model artefacts (``.cdm``, ``.mom``) to JSON.

Both formats are ``NSKeyedArchiver`` binary plists: a ``.cdm`` is a compiled
``.xcmappingmodel`` whose root is an ``NSMappingModel`` (``v1_to_v2.cdm`` in
``PopnRhythmin.app`` migrates ``ScoreData.momd`` v1 to v2), and a ``.mom`` is a
compiled ``.xcdatamodel`` whose root is an ``NSManagedObjectModel``. The
``.omo`` beside the current-version ``.mom`` is deliberately unsupported: it is
Core Data's undocumented load-time cache of that same model (``momv2$<digest>``
magic, custom offset-table binary) and carries no information the ``.mom``
lacks.

**Default (deserialised object):** replicates what ``NSKeyedUnarchiver`` plus
Core Data would materialise, dispatching on the archive's root class.

For an ``NSMappingModel`` (``.cdm``):

* each ``NSEntityMapping`` becomes an object with plain ``name``,
  ``mappingType`` (add/remove/copy/transform/custom), source/destination entity
  names, hex version hashes, migration policy class, and its attribute and
  relationship mappings;
* every archived ``NSExpression`` tree is rendered back into its canonical
  source-string form, mirroring Foundation's ``description`` conventions:
  ``$source.category`` for ``valueForKeyPath:`` function expressions,
  ``FUNCTION(operand, "selector:", args...)`` for other functions, and
  ``FETCH(request, context)`` for the private ``NSFetchRequestExpression`` —
  the same strings the Xcode mapping-model editor shows;
* ``NSDictionary``/``NSArray`` values (user info, property transforms) are
  flattened to plain JSON objects/arrays.

For an ``NSManagedObjectModel`` (``.mom``):

* each ``NSEntityDescription`` becomes an object with its class name,
  super/sub-entities, renaming identifier, and properties;
* each ``NSAttributeDescription`` carries its readable type (integer32,
  string, date, ...), value class name, optionality, indexed flag, default
  value, and validation predicates rendered as readable strings
  (``SELF >= 0``); relationships carry destination, inverse, count bounds,
  and delete rule.

**``--archive`` (lossless keyed-archive dump):** decodes the raw archive object
graph instead (of any ``NSKeyedArchiver`` plist, whatever its root class), as
close to lossless as JSON allows:

* every archived instance becomes an object carrying its ``$class`` name and
  all archived fields, with ``UID`` references resolved in place;
* objects referenced more than once are emitted in full on first use with an
  ``$id`` marker, and as ``{"$ref": id}`` afterwards, so shared structure and
  cycles survive the conversion;
* ``NSArray``/``NSSet`` variants become ``{"$class": ..., "items": [...]}`` and
  ``NSDictionary`` variants ``{"$class": ..., "entries": {...}}``;
* binary data (the entity version hashes) is hex-encoded under ``$data``;
* ``NSMappingType`` and ``NSExpressionType`` gain readable ``$mappingType`` /
  ``$expressionType`` annotations alongside the raw values (no loss).

**``--sql`` (effective migration SQL, ``.cdm`` only):** prints the SQLite
statements the migration amounts to, using Core Data's ``Z`` conventions (table
``Z<ENTITY>``, columns ``Z<ATTRIBUTE>`` plus ``Z_PK``/``Z_ENT``/``Z_OPT``,
and the ``Z_PRIMARYKEY`` bookkeeping table). Each copy mapping becomes the
single-statement ``INSERT INTO ... SELECT`` equivalent against an ``ATTACH``\ ed
old store; add mappings contribute only their ``CREATE TABLE``. Core Data
really routes every row through ``NSMigrationManager`` in memory, so this is
the net effect, not a transcript. Pass ``--mom`` with the compiled
*destination* model (``ScoreData.momd/ScoreData_v2.mom``) to give columns
their real types and to number ``Z_ENT`` from the full entity list; without
it, columns are emitted untyped (valid in SQLite) from the mapping alone.
Anything untranslatable (a predicate other than ``TRUEPREDICATE``, a value
expression that is not ``$source.<key>``) is surfaced as an SQL comment
rather than silently dropped.

Usage::

    tools/coredata_dump.py v1_to_v2.cdm              # deserialised model JSON
    tools/coredata_dump.py ScoreData.momd/ScoreData_v2.mom
    tools/coredata_dump.py v1_to_v2.cdm --archive    # lossless archive dump
    tools/coredata_dump.py v1_to_v2.cdm --sql --mom ScoreData.momd/ScoreData_v2.mom
    tools/coredata_dump.py v1_to_v2.cdm -o v1_to_v2.json
"""

from __future__ import annotations

import argparse
import json
import plistlib
import re
import sys
from typing import Any

# NSEntityMappingType (CoreData/NSEntityMapping.h).
ENTITY_MAPPING_TYPES = {
    0: 'undefined',
    1: 'custom',
    2: 'add',
    3: 'remove',
    4: 'copy',
    5: 'transform',
}

# NSExpressionType (Foundation/NSExpression.h) plus the private values that
# appear in compiled mapping models (10 and 50).
EXPRESSION_TYPES = {
    0: 'constantValue',
    1: 'evaluatedObject',
    2: 'variable',
    3: 'keyPath',
    4: 'function',
    5: 'unionSet',
    6: 'intersectSet',
    7: 'minusSet',
    10: 'keyPathSpecifier',
    13: 'subquery',
    14: 'aggregate',
    15: 'anyKey',
    19: 'block',
    20: 'conditional',
    50: 'fetchRequest',
}

COLLECTION_CLASSES = ('NSArray', 'NSMutableArray', 'NSSet', 'NSMutableSet',
                      'NSOrderedSet', 'NSMutableOrderedSet')

# NSAttributeType (CoreData/NSAttributeDescription.h).
ATTRIBUTE_TYPE_NAMES = {
    0: 'undefined',
    100: 'integer16',
    200: 'integer32',
    300: 'integer64',
    400: 'decimal',
    500: 'double',
    600: 'float',
    700: 'string',
    800: 'boolean',
    900: 'date',
    1000: 'binaryData',
    1800: 'UUID',
    1900: 'URI',
    2000: 'transformable',
    2100: 'objectID',
}

# NSPredicateOperatorType (Foundation/NSComparisonPredicate.h).
PREDICATE_OPERATORS = {
    0: '<',
    1: '<=',
    2: '>',
    3: '>=',
    4: '==',
    5: '!=',
    6: 'MATCHES',
    7: 'LIKE',
    8: 'BEGINSWITH',
    9: 'ENDSWITH',
    10: 'IN',
    99: 'CONTAINS',
    100: 'BETWEEN',
}

# NSDeleteRule (CoreData/NSRelationshipDescription.h).
DELETE_RULES = {
    0: 'noAction',
    1: 'nullify',
    2: 'cascade',
    3: 'deny',
}

# NSAttributeType (CoreData/NSAttributeDescription.h) to the column types the
# SQLite store emits.
ATTRIBUTE_SQL_TYPES = {
    100: 'INTEGER',
    200: 'INTEGER',
    300: 'INTEGER',
    400: 'DECIMAL',
    500: 'FLOAT',
    600: 'FLOAT',
    700: 'VARCHAR',
    800: 'INTEGER',
    900: 'TIMESTAMP',
    1000: 'BLOB',
    2000: 'BLOB',
}

FETCH_PATTERN = re.compile(
    r'FETCH\(FUNCTION\(\$manager, "fetchRequestForSourceEntityNamed:predicateString:", '
    r'"([^"]+)", "([^"]*)"\), \$manager\.sourceContext\)')
SOURCE_KEY_PATTERN = re.compile(r'^\$source\.(\w+)$')


class ArchiveDecoder:
    """Resolve an NSKeyedArchiver object graph into JSON-compatible values.

    With ``share_refs`` (the archive dump), objects referenced more than once
    are emitted once with ``$id`` and thereafter as ``{"$ref": id}``. Without
    it (the deserialised model), shared objects are expanded at every use, as
    a real unarchive would hand out the same instance in both places.
    """

    def __init__(self, archive: dict[str, Any], *, share_refs: bool = True) -> None:
        if archive.get('$archiver') != 'NSKeyedArchiver':
            raise ValueError(f'not an NSKeyedArchiver archive: {archive.get("$archiver")!r}')
        self.objects: list[Any] = archive['$objects']
        self.share_refs = share_refs
        self.refcounts = self._count_references(archive)
        self.emitted: set[int] = set()
        self.in_progress: set[int] = set()

    def _count_references(self, archive: dict[str, Any]) -> dict[int, int]:
        """Count how many times each UID is referenced (``$class`` excluded)."""
        counts: dict[int, int] = {}

        def visit(value: Any) -> None:
            if isinstance(value, plistlib.UID):
                counts[value.data] = counts.get(value.data, 0) + 1
            elif isinstance(value, list):
                for item in value:
                    visit(item)
            elif isinstance(value, dict):
                for key, item in value.items():
                    if key != '$class':
                        visit(item)

        visit(archive['$top'])
        for obj in self.objects:
            visit(obj)
        return counts

    def class_name(self, instance: dict[str, Any]) -> str:
        descriptor = self.objects[instance['$class'].data]
        return descriptor.get('$classname', '?')

    def decode_uid(self, uid: int) -> Any:
        obj = self.objects[uid]
        if uid == 0 and obj == '$null':
            return None
        if not isinstance(obj, dict):
            return self.decode_value(obj)
        # Instances only: share/cycle handling applies to the object graph.
        if self.share_refs and uid in self.emitted:
            return {'$ref': uid}
        if uid in self.in_progress:
            return {'$ref': uid}
        self.in_progress.add(uid)
        try:
            decoded = self.decode_instance(obj)
        finally:
            self.in_progress.discard(uid)
        if self.share_refs and self.refcounts.get(uid, 0) > 1:
            decoded = {'$id': uid, **decoded}
            self.emitted.add(uid)
        return decoded

    def decode_instance(self, instance: dict[str, Any]) -> dict[str, Any]:
        if '$classname' in instance:
            # A class descriptor reached directly (unusual); emit verbatim.
            return dict(instance)
        name = self.class_name(instance)
        if name in COLLECTION_CLASSES:
            items = [self.decode_value(v) for v in instance.get('NS.objects', [])]
            return {'$class': name, 'items': items}
        if 'NS.keys' in instance:
            keys = [self.decode_value(k) for k in instance['NS.keys']]
            values = [self.decode_value(v) for v in instance.get('NS.objects', [])]
            if all(isinstance(k, str) for k in keys):
                return {'$class': name, 'entries': dict(zip(keys, values))}
            return {'$class': name, 'entries': [list(pair) for pair in zip(keys, values)]}
        if 'NS.string' in instance:
            return {'$class': name, 'string': self.decode_value(instance['NS.string'])}
        # Decode fields in sorted key order so that, with the key-sorted JSON
        # output, shared objects are expanded at the first position a reader
        # encounters and later positions carry the ``$ref``.
        decoded: dict[str, Any] = {'$class': name}
        for key, value in sorted(instance.items()):
            if key == '$class':
                continue
            decoded[key] = self.decode_value(value)
        if isinstance(decoded.get('NSMappingType'), int):
            decoded['$mappingType'] = ENTITY_MAPPING_TYPES.get(
                decoded['NSMappingType'], f'unknown ({decoded["NSMappingType"]})')
        if isinstance(decoded.get('NSExpressionType'), int):
            decoded['$expressionType'] = EXPRESSION_TYPES.get(
                decoded['NSExpressionType'], f'unknown ({decoded["NSExpressionType"]})')
        return decoded

    def decode_value(self, value: Any) -> Any:
        if isinstance(value, plistlib.UID):
            return self.decode_uid(value.data)
        if isinstance(value, bytes):
            return {'$data': value.hex()}
        if isinstance(value, list):
            return [self.decode_value(v) for v in value]
        if isinstance(value, dict):
            return self.decode_instance(value)
        return value

    def decode_top(self, archive: dict[str, Any]) -> dict[str, Any]:
        top = {key: self.decode_value(value) for key, value in archive['$top'].items()}
        return {
            '$archiver': archive['$archiver'],
            '$version': archive.get('$version'),
            '$top': top,
        }


def render_constant(value: Any) -> str:
    if value is None:
        return 'nil'
    if isinstance(value, bool):
        return 'YES' if value else 'NO'
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, dict) and '$data' in value:
        return f'<{value["$data"]}>'
    return str(value)


def render_expression(exp: dict[str, Any] | None) -> str | None:
    """Render a decoded NSExpression tree as its canonical source string.

    Mirrors the ``description`` conventions of Foundation's expression
    classes, which are also the strings the Xcode mapping-model editor shows
    (``$source.category``, ``FUNCTION(...)``, ``FETCH(...)``).
    """
    if exp is None:
        return None
    expression_type = exp.get('NSExpressionType')
    if expression_type == 0:
        return render_constant(exp.get('NSConstantValue'))
    if expression_type == 1:
        return 'SELF'
    if expression_type == 2:
        return '$' + exp['NSVariable']
    if expression_type in (3, 10):
        return exp['NSKeyPath']
    if expression_type == 4:
        operand = render_expression(exp.get('NSOperand'))
        selector = exp['NSSelectorName']
        arguments = exp.get('NSArguments') or {}
        items = arguments.get('items', [])
        if selector == 'valueForKeyPath:' and len(items) == 1:
            return f'{operand}.{render_expression(items[0])}'
        rendered = ', '.join(render_expression(a) or 'nil' for a in items)
        suffix = f', {rendered}' if rendered else ''
        return f'FUNCTION({operand}, {json.dumps(selector)}{suffix})'
    if expression_type == 50:
        request = render_expression(exp.get('NSFRExpression'))
        context = render_expression(exp.get('NSMOCExpression'))
        count = ', COUNT' if exp.get('NSCountOnlyFlag') else ''
        return f'FETCH({request}, {context}{count})'
    kind = EXPRESSION_TYPES.get(expression_type, 'unknown')
    return f'<expression type {expression_type} ({kind})>'


def render_predicate(predicate: Any) -> Any:
    """Render a decoded NSPredicate as a readable string, best effort.

    Anything unrecognised falls back to the simplified raw structure rather
    than being dropped.
    """
    if not isinstance(predicate, dict):
        return simplify_value(predicate)
    class_name = predicate.get('$class')
    if class_name == 'NSComparisonPredicate':
        operator = predicate.get('NSPredicateOperator') or {}
        operator_type = operator.get('NSOperatorType')
        symbol = PREDICATE_OPERATORS.get(operator_type, f'<operator {operator_type}>')
        left = render_expression(predicate.get('NSLeftExpression'))
        right = render_expression(predicate.get('NSRightExpression'))
        return f'{left} {symbol} {right}'
    if class_name == 'NSCompoundPredicate':
        joiner = {0: ' AND NOT ', 1: ' AND ', 2: ' OR '}.get(
            predicate.get('NSCompoundPredicateType'), ' ?? ')
        group = predicate.get('NSSubpredicates') or {}
        parts = [str(render_predicate(p)) for p in group.get('items', [])]
        return '(' + joiner.join(parts) + ')'
    if class_name == 'NSTruePredicate':
        return 'TRUEPREDICATE'
    if class_name == 'NSFalsePredicate':
        return 'FALSEPREDICATE'
    return simplify_value(predicate)


def simplify_value(value: Any) -> Any:
    """Flatten decoded container wrappers to plain JSON values."""
    if isinstance(value, dict):
        if '$data' in value:
            return value['$data']
        if 'items' in value and '$class' in value:
            return [simplify_value(v) for v in value['items']]
        if 'entries' in value and '$class' in value:
            entries = value['entries']
            if isinstance(entries, dict):
                return {k: simplify_value(v) for k, v in entries.items()}
            return [[simplify_value(k), simplify_value(v)] for k, v in entries]
        return {k: simplify_value(v) for k, v in value.items() if k != '$class'}
    if isinstance(value, list):
        return [simplify_value(v) for v in value]
    return value


def build_property_mapping(pm: dict[str, Any]) -> dict[str, Any]:
    return {
        'name': pm.get('NSDestinationPropertyName'),
        'valueExpression': render_expression(pm.get('NSValueExpression')),
        'propertyTransforms': simplify_value(pm.get('NSPropertyTransforms')),
        'userInfo': simplify_value(pm.get('NSUserInfo')),
    }


def build_entity_mapping(em: dict[str, Any]) -> dict[str, Any]:
    def mappings(key: str) -> list[dict[str, Any]]:
        group = em.get(key)
        items = group.get('items', []) if isinstance(group, dict) else []
        return [build_property_mapping(pm) for pm in items]

    def hash_hex(key: str) -> str | None:
        value = em.get(key)
        return value.get('$data') if isinstance(value, dict) else None

    return {
        'name': em.get('NSMappingName'),
        'mappingType': ENTITY_MAPPING_TYPES.get(em.get('NSMappingType'),
                                                f'unknown ({em.get("NSMappingType")})'),
        'sourceEntityName': em.get('NSSourceEntityName'),
        'destinationEntityName': em.get('NSDestinationEntityName'),
        'sourceEntityVersionHash': hash_hex('NSSourceEntityVersionHash'),
        'destinationEntityVersionHash': hash_hex('NSDestinationEntityVersionHash'),
        'sourceExpression': render_expression(em.get('NSSourceExpression')),
        'entityMigrationPolicyClassName': em.get('NSEntityMigrationPolicyClassName'),
        'attributeMappings': mappings('NSAttributeMappings'),
        'relationshipMappings': mappings('NSRelationshipMappings'),
        'userInfo': simplify_value(em.get('NSUserInfo')),
    }


def build_model(root: dict[str, Any]) -> dict[str, Any]:
    if root.get('$class') != 'NSMappingModel':
        raise ValueError(f'root object is {root.get("$class")!r}, not NSMappingModel; '
                         'use --archive for a raw dump')
    group = root.get('NSEntityMappings') or {}
    # NSEntityMappingsByName is derived (keyed by mapping name), so it is not
    # repeated here.
    return {
        'entityMappings': [build_entity_mapping(em) for em in group.get('items', [])],
    }


def build_attribute(prop: dict[str, Any]) -> dict[str, Any]:
    attribute_type = prop.get('NSAttributeType')
    validation = prop.get('NSValidationPredicates')
    predicates = validation.get('items', []) if isinstance(validation, dict) else []
    return {
        'type': ATTRIBUTE_TYPE_NAMES.get(attribute_type, f'unknown ({attribute_type})'),
        'valueClassName': prop.get('NSAttributeValueClassName'),
        'optional': bool(prop.get('NSIsOptional', False)),
        'indexed': bool(prop.get('NSIsIndexed', False)),
        'defaultValue': simplify_value(prop.get('NSDefaultValue')),
        'renamingIdentifier': prop.get('NSRenamingIdentifier'),
        'valueTransformerName': prop.get('NSValueTransformerName'),
        'validationPredicates': [render_predicate(p) for p in predicates] or None,
        'userInfo': simplify_value(prop.get('NSUserInfo')),
    }


def build_relationship(prop: dict[str, Any]) -> dict[str, Any]:
    def related_name(key: str, name_key: str) -> Any:
        value = prop.get(key)
        if isinstance(value, dict):
            return value.get(name_key, value)
        return value

    return {
        'destinationEntity': related_name('NSDestinationEntity', 'NSEntityName'),
        'inverseRelationship': related_name('NSInverseRelationship', 'NSPropertyName'),
        'minCount': prop.get('NSMinCount'),
        'maxCount': prop.get('NSMaxCount'),
        'deleteRule': DELETE_RULES.get(prop.get('NSDeleteRule')),
        'optional': bool(prop.get('NSIsOptional', False)),
        'ordered': bool(prop.get('NSIsOrdered', False)),
        'renamingIdentifier': prop.get('NSRenamingIdentifier'),
        'userInfo': simplify_value(prop.get('NSUserInfo')),
    }


def build_entity(entity: dict[str, Any]) -> dict[str, Any]:
    properties = (entity.get('NSProperties') or {}).get('entries', {})
    attributes: dict[str, Any] = {}
    relationships: dict[str, Any] = {}
    other_properties: dict[str, Any] = {}
    for name, prop in sorted(properties.items()):
        if not isinstance(prop, dict):
            other_properties[name] = prop
        elif 'NSAttributeType' in prop:
            attributes[name] = build_attribute(prop)
        elif 'NSDestinationEntity' in prop:
            relationships[name] = build_relationship(prop)
        else:
            other_properties[name] = simplify_value(prop)
    subentities = entity.get('NSSubentities')
    subentity_names = (sorted(subentities['entries'])
                       if isinstance(subentities, dict) and 'entries' in subentities
                       else [])
    superentity = entity.get('NSSuperentity')
    return {
        'className': entity.get('NSClassNameForEntity'),
        'superentity': (superentity.get('NSEntityName', superentity)
                        if isinstance(superentity, dict) else superentity),
        'subentities': subentity_names,
        'renamingIdentifier': entity.get('NSRenamingIdentifier'),
        'versionHashModifier': entity.get('NSVersionHashModifier'),
        'attributes': attributes,
        'relationships': relationships,
        'otherProperties': other_properties or None,
        'userInfo': simplify_value(entity.get('NSUserInfo')),
    }


def build_managed_object_model(root: dict[str, Any]) -> dict[str, Any]:
    entities = (root.get('NSEntities') or {}).get('entries', {})
    return {
        'entities': {name: build_entity(entity)
                     for name, entity in sorted(entities.items())},
        'versionIdentifiers': simplify_value(root.get('NSVersionIdentifiers')),
        'fetchRequestTemplates': simplify_value(root.get('NSFetchRequestTemplates')),
    }


def load_mom_column_types(path: str) -> dict[str, dict[str, str]]:
    """Read a compiled model (``.mom``) and return entity -> attribute -> SQL type."""
    with open(path, 'rb') as f:
        archive = plistlib.load(f)
    decoder = ArchiveDecoder(archive, share_refs=False)
    root = decoder.decode_value(archive['$top']['root'])
    if root.get('$class') != 'NSManagedObjectModel':
        raise ValueError(f'root object of {path} is {root.get("$class")!r}, '
                         'not NSManagedObjectModel')
    entities = (root.get('NSEntities') or {}).get('entries', {})
    types: dict[str, dict[str, str]] = {}
    for entity_name, entity in entities.items():
        properties = (entity.get('NSProperties') or {}).get('entries', {})
        columns: dict[str, str] = {}
        for property_name, prop in properties.items():
            if isinstance(prop, dict) and 'NSAttributeType' in prop:
                columns[property_name] = ATTRIBUTE_SQL_TYPES.get(
                    prop['NSAttributeType'], 'BLOB')
        types[entity_name] = columns
    return types


def build_sql(model: dict[str, Any],
              mom_types: dict[str, dict[str, str]] | None) -> str:
    """Emit the effective SQLite script for a deserialised mapping model.

    ``Z_ENT`` ordinals follow Core Data's assignment (position in the model's
    name-sorted entity list); with ``--mom`` they come from the full
    destination model, otherwise from the mapped entities alone.
    """
    mappings = model['entityMappings']
    destinations = sorted(em['destinationEntityName'] for em in mappings
                          if em['destinationEntityName'])
    ordinal_names = sorted(mom_types) if mom_types else destinations
    ordinals = {name: index + 1 for index, name in enumerate(ordinal_names)}
    lines = [
        '-- Effective SQLite statements for this mapping model. Core Data performs a',
        '-- heavyweight migration by rebuilding the store and pumping every row through',
        '-- NSMigrationManager in memory; each copy mapping below is shown as its',
        '-- single-statement INSERT ... SELECT equivalent.',
        "ATTACH DATABASE 'old_store.sqlite' AS src;",
        'BEGIN EXCLUSIVE;',
        '',
    ]
    for em in sorted(mappings, key=lambda m: m['destinationEntityName'] or ''):
        destination = em['destinationEntityName']
        name = em['name']
        if destination is None:
            lines += [f"-- {name}: {em['mappingType']} mapping with no destination "
                      'entity; nothing to emit.', '']
            continue
        table = 'Z' + destination.upper()
        attribute_mappings = sorted(em['attributeMappings'], key=lambda pm: pm['name'] or '')
        if mom_types and destination in mom_types:
            columns = {attr: mom_types[destination][attr]
                       for attr in sorted(mom_types[destination])}
        else:
            columns = {pm['name']: '' for pm in attribute_mappings}
        lines.append(f"-- {name} ({em['mappingType']})")
        lines.append(f'CREATE TABLE {table} (')
        declarations = ['Z_PK INTEGER PRIMARY KEY', 'Z_ENT INTEGER', 'Z_OPT INTEGER']
        declarations += [f'Z{attr.upper()} {sql_type}'.rstrip()
                         for attr, sql_type in columns.items()]
        lines += [f'  {decl},' for decl in declarations[:-1]]
        lines += [f'  {declarations[-1]}', ');']
        if em['relationshipMappings']:
            lines.append('-- Relationship mappings are present but not translated here.')
        source_expression = em['sourceExpression']
        if source_expression is None:
            lines.append(f'-- {em["mappingType"]} mapping: the table starts empty.')
        else:
            match = FETCH_PATTERN.fullmatch(source_expression)
            if match is None:
                lines.append(f'-- Source expression not translated: {source_expression}')
            else:
                source_entity, predicate = match.groups()
                if predicate != 'TRUEPREDICATE':
                    lines.append(f'-- Source predicate not translated: {predicate}')
                select_terms = ['Z_PK', f'{ordinals[destination]} AS Z_ENT', 'Z_OPT']
                insert_columns = ['Z_PK', 'Z_ENT', 'Z_OPT']
                for pm in attribute_mappings:
                    insert_columns.append('Z' + pm['name'].upper())
                    expression = pm['valueExpression']
                    key = SOURCE_KEY_PATTERN.match(expression) if expression else None
                    if key is not None:
                        select_terms.append('Z' + key.group(1).upper())
                    elif expression is None:
                        select_terms.append('NULL')
                    else:
                        select_terms.append(f'NULL /* {expression} */')
                lines.append(f'INSERT INTO {table} ({", ".join(insert_columns)})')
                lines.append(f'  SELECT {", ".join(select_terms)}')
                lines.append(f'  FROM src.Z{source_entity.upper()};')
        lines.append('')
    lines += [
        'CREATE TABLE Z_PRIMARYKEY (Z_ENT INTEGER PRIMARY KEY, Z_NAME VARCHAR,',
        '                           Z_SUPER INTEGER, Z_MAX INTEGER);',
    ]
    for destination in destinations:
        table = 'Z' + destination.upper()
        lines.append('INSERT INTO Z_PRIMARYKEY (Z_ENT, Z_NAME, Z_SUPER, Z_MAX)')
        lines.append(f"  SELECT {ordinals[destination]}, '{destination}', 0, "
                     f'COALESCE(MAX(Z_PK), 0) FROM {table};')
    lines += [
        '-- Z_METADATA (Z_VERSION, Z_UUID, Z_PLIST) is written by Core Data with the new',
        "-- model's version-hash plist; the blob is not reproducible here.",
        'COMMIT;',
        'DETACH DATABASE src;',
    ]
    return '\n'.join(lines) + '\n'


def convert(path: str, *, archive_mode: bool) -> dict[str, Any]:
    with open(path, 'rb') as f:
        archive = plistlib.load(f)
    if archive_mode:
        return ArchiveDecoder(archive).decode_top(archive)
    decoder = ArchiveDecoder(archive, share_refs=False)
    root = decoder.decode_value(archive['$top']['root'])
    root_class = root.get('$class') if isinstance(root, dict) else None
    if root_class == 'NSMappingModel':
        return build_model(root)
    if root_class == 'NSManagedObjectModel':
        return build_managed_object_model(root)
    raise ValueError(f'unsupported root object {root_class!r}; '
                     'use --archive for a raw dump')


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split('\n', 1)[0])
    ap.add_argument('file', help='path to the .cdm or .mom file')
    ap.add_argument('--archive', action='store_true',
                    help='dump the raw keyed archive losslessly instead of the '
                         'deserialised model')
    ap.add_argument('--sql', action='store_true',
                    help='print the effective SQLite migration script instead of JSON '
                         '(mapping models only)')
    ap.add_argument('--mom', metavar='FILE',
                    help='compiled destination model (.mom) supplying column types '
                         'and Z_ENT ordinals for --sql')
    ap.add_argument('-o', '--output', metavar='FILE',
                    help='write the output to FILE instead of stdout')
    args = ap.parse_args(argv)
    if args.archive and args.sql:
        ap.error('--archive and --sql are mutually exclusive')
    if args.mom and not args.sql:
        ap.error('--mom only applies to --sql')
    try:
        if args.sql:
            model = convert(args.file, archive_mode=False)
            if 'entityMappings' not in model:
                ap.error('--sql requires a mapping model (.cdm)')
            mom_types = load_mom_column_types(args.mom) if args.mom else None
            text = build_sql(model, mom_types)
        else:
            result = convert(args.file, archive_mode=args.archive)
            text = json.dumps(result, indent=2, sort_keys=True, ensure_ascii=False) + '\n'
    except ValueError as e:
        print(f'error: {e}', file=sys.stderr)
        return 1
    if args.output:
        with open(args.output, 'w', encoding='utf-8') as f:
            f.write(text)
    else:
        sys.stdout.write(text)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
