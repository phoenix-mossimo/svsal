xquery version "3.1";

module namespace sal-util = "http://salamanca/sal-util";

import module namespace config = "http://salamanca/config" at "config.xqm";
import module namespace app        = "http://salamanca/app"    at "app.xql";

declare namespace tei = "http://www.tei-c.org/ns/1.0";


(:
~ Makes a copy of a node tree, to be used for making copies of subtrees on-the-fly for not having to process the whole document
    (supposed to increase speed especially where "intersect" statements are applied).
:)
declare function sal-util:copy($node as element()) as node() {
    (:element {node-name($node)}
    {$node/@*,
        for $child in $node/node()
             return if ($child instance of element()) then 
                sal-util:copy($child)
             else $child
    }:)
    (:util:deep-copy($node):)
    (: this seems to be the fastest option: :)
    let $xsl :=
        <xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
            <xsl:template match="@*|node()">
                <xsl:copy>
                    <xsl:apply-templates select="@*|node()"/>
                </xsl:copy>
              </xsl:template>
          </xsl:stylesheet>
    return
        transform:transform($node, $xsl, ())
};


(: Normalizes work, author, lemma, news, and working paper ids (and returns everything else as-is :)
declare function sal-util:normalizeId($id as xs:string?) as xs:string? {
    if ($id) then
        if (matches($id, '^[wW]\d{4}(_[vV][oO][lL]\d{2})?$')) then translate($id, 'wvLO', 'WVlo')
        else if (matches($id, '^[lLaAnN]\d{4}$')) then upper-case($id) (: lemma, author, news :)
        else if (matches($id, '^[wW][pP]\d{4}$')) then upper-case($id)
        else $id
    else ()
};


(: validate work/author/... IDs :)

declare function sal-util:AUTexists($aid as xs:string?) as xs:boolean {
    if ($aid) then boolean(doc($config:tei-meta-root || '/' || 'sources-list.xml')/tei:TEI/tei:text//tei:author[lower-case(substring-after(@ref, 'author:')) eq lower-case($aid)])
    else false()
};

(: 1 = valid & available; 0 = valid, but not yet available; -1 = not valid :)
declare function sal-util:AUTvalidateId($aid as xs:string?) as xs:integer {
    if ($aid and matches($aid, '^[aA]\d{4}$')) then
        (: TODO: additional condition when author articles are available - currently this will always resolve to -1 :)
        if (sal-util:AUTexists(sal-util:normalizeId($aid))) then 0
        else -1
    else -1    
};

declare function sal-util:LEMexists($lid as xs:string?) as xs:boolean {
    (: TODO when we have a list of lemma ids :)
    (:if ($lid) then boolean(doc(.../...) eq $lid])
    else :)
    false()
};

(: 1 = valid & available; 0 = valid, but not yet available; -1 = not valid :)
declare function sal-util:LEMvalidateId($lid as xs:string?) as xs:integer {
    if ($lid and matches($lid, '^[lL]\d{4}$')) then
        (: TODO: additional conditions when lemmata/entries are available - currently this will always resolve to -1 :)
        if (sal-util:LEMexists(sal-util:normalizeId($lid))) then 0
        else -1
    else -1    
};

(: 1 = WP is published ; 0 = WP not yet available (not yet defined) ; -1 = WP does not exist :)
declare function sal-util:WPvalidateId($wpid as xs:string?) as xs:integer {
    if ($wpid and matches($wpid, '^[wW][pP]\d{4}$') and sal-util:WPisPublished($wpid)) then 1
    else -1
};

declare function sal-util:WPisPublished($wpid as xs:string?) as xs:boolean {
    boolean($wpid and doc-available($config:tei-workingpapers-root || '/' || upper-case($wpid) || '.xml')) 
};

declare function sal-util:WRKexists($wid as xs:string?) as xs:boolean {
    if ($wid) then boolean(doc($config:tei-meta-root || '/' || 'sources-list.xml')/tei:TEI/tei:text//tei:bibl[lower-case(substring-after(@corresp, 'work:')) eq lower-case($wid)])
    else false()
};

(: 2 = valid, full data available; 1 = valid, but only metadata available; 0 = valid, but not yet available; -1 = not valid :)
declare function sal-util:WRKvalidateId($wid as xs:string?) as xs:integer {
    if ($wid and matches($wid, '^[wW]\d{4}(_Vol\d{2})?$')) then
        if (sal-util:WRKisPublished($wid)) then 2
        else if (doc-available($config:tei-works-root || '/' || sal-util:normalizeId($wid) || '.xml')) then 1
        else if (sal-util:WRKexists($wid)) then 0
        else -1
    else -1    
};

declare function sal-util:WRKisPublished($wid as xs:string) as xs:boolean {
    let $workId := sal-util:normalizeId($wid)
    let $status :=  if (doc-available($config:tei-works-root || '/' || $workId || '.xml')) then 
                        doc($config:tei-works-root || '/' || $workId || '.xml')/tei:TEI/tei:teiHeader/tei:revisionDesc/@status/string()
                    else 'no_status'
    let $publishedStatus := ('g_enriched_approved', 'h_revised', 'i_revised_approved', 'z_final')
    return $status = $publishedStatus
};

(: 1 = valid & existing ; 0 = not existing ; -1 = no dataset found for $wid :)
(:declare function sal-util:WRKvalidatePassageId($wid as xs:string?, $passage as xs:string?) as xs:integer {
    if ($wid and matches($wid, '^[wW]\d{4}(_Vol\d{2})?$')) then
        if (sal-util:WRKisPublished($wid)) then 2
        else if (doc-available($config:tei-works-root || '/' || sal-util:normalizeId($wid) || '.xml')) then 1
        else if (sal-util:WRKexists($wid)) then 0
        else -1
    else -1    
};:)

(: concepts? :)

