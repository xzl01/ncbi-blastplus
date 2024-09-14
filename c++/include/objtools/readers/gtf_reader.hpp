 /*  $Id: gtf_reader.hpp 674645 2023-11-01 12:38:20Z ivanov $
 * ===========================================================================
 *
 *                            PUBLIC DOMAIN NOTICE
 *               National Center for Biotechnology Information
 *
 *  This software/database is a "United States Government Work" under the
 *  terms of the United States Copyright Act.  It was written as part of
 *  the author's official duties as a United States Government employee and
 *  thus cannot be copyrighted.  This software/database is freely available
 *  to the public for use. The National Library of Medicine and the U.S.
 *  Government have not placed any restriction on its use or reproduction.
 *
 *  Although all reasonable efforts have been taken to ensure the accuracy
 *  and reliability of the software and data, the NLM and the U.S.
 *  Government do not and cannot warrant the performance or results that
 *  may be obtained by using this software or data. The NLM and the U.S.
 *  Government disclaim all warranties, express or implied, including
 *  warranties of performance, merchantability or fitness for any particular
 *  purpose.
 *
 *  Please cite the author in any work or product based on this material.
 *
 * ===========================================================================
 *
 * Author: Frank Ludwig
 *
 * File Description:
 *   BED file reader
 *
 */

#ifndef OBJTOOLS_READERS___GTF_READER__HPP
#define OBJTOOLS_READERS___GTF_READER__HPP

#include <corelib/ncbistd.hpp>
#include <objtools/readers/gff2_reader.hpp>
#include <set>
#include <map>

BEGIN_NCBI_SCOPE

BEGIN_SCOPE(objects) // namespace ncbi::objects::

class CGtfLocationMerger;
class CGtfAttributes;

CGtfAttributes g_GetIntersection(const CGtfAttributes& x, const CGtfAttributes& y);

//  ============================================================================
class CGtfAttributes
//  ============================================================================
{
public:
  //  using MultiValue = vector<string>;
    using MultiValue = set<string>;

    using MultiAttributes = map<string, MultiValue>;

    const MultiAttributes&
    Get() const
    {
        return mAttributes;
    };

    string
    ValueOf(
        const string& key) const
    {
        MultiValue values;
        GetValues(key, values);
        if (values.size() == 1) {
            return *(values.begin());
        }
        return "";
    }

    bool
    HasValue(
        const string& key,
        const string& value = "") const
    {
        auto it = mAttributes.find(key);
        if (it == mAttributes.end()) {
            return false;
        }
        if (value.empty()) {
            return true;
        }

        const auto& values = it->second;
        if (values.empty()) {
            return false;
        }
        return (values.find(value) != values.end());
    };

    void
    GetValues(
        const string& key,
        MultiValue& values) const
    {
        if (auto it = mAttributes.find(key); it != mAttributes.end()) {
            values = it->second;
        }
        else {
            values.clear();
        }
    };


    void
    AddValue(
        const string& key,
        const string& value)
    {
        auto kit = mAttributes.find(key);
        if (kit == mAttributes.end()) {
            kit = mAttributes.emplace(key, MultiValue()).first;
        }
        kit->second.insert(value);
    };

    void 
    Remove(const string& key)
    {
        auto it = mAttributes.find(key);
        if (it == mAttributes.end()) {
            return;
        }
        mAttributes.erase(it);
    }

    void 
    RemoveValue(const string& key, const string& value)
    {
        auto it = mAttributes.find(key);
        if (it == mAttributes.end()) {
            return;
        }

        auto& values = it->second;
        if (auto vit = values.find(value); vit != values.end()) {
            values.erase(vit);
            if (values.empty()) {
                mAttributes.erase(it);
            }
        }
    }

    friend CGtfAttributes g_GetIntersection(const CGtfAttributes& x, const CGtfAttributes& y);
protected:
    MultiAttributes mAttributes;
};


//  ============================================================================
class CGtfReadRecord
//  ============================================================================
    : public CGff2Record
{
public:
    CGtfReadRecord(): CGff2Record() {
    };
    ~CGtfReadRecord() {};

    const CGtfAttributes&
    GtfAttributes() const
    {
        return mAttributes;
    };

    string
    GeneKey() const
    {
        string geneId = mAttributes.ValueOf("gene_id");
        if (geneId.empty()) {
            cerr << "Unexpected: GTF feature without a gene_id." << endl;
        }
        return geneId;
    };

    string
    FeatureKey() const
    {
        static unsigned int tidCounter(1);
        if (Type() == "gene") {
            return GeneKey();
        }

        string transcriptId = mAttributes.ValueOf("transcript_id");
        if (transcriptId.empty()) {
            transcriptId = "t" + NStr::IntToString(tidCounter++);
        }
        return GeneKey() + "_" + transcriptId;
    }

    string TranscriptId() const
    {
        return mAttributes.ValueOf("transcript_id");
    }

protected:
    bool xAssignAttributesFromGff(
        const string&,
        const string& );

    CGtfAttributes mAttributes;
};

//  ----------------------------------------------------------------------------
class NCBI_XOBJREAD_EXPORT CGtfReader
//  ----------------------------------------------------------------------------
    : public CGff2Reader
{
public:
    enum EGtfFlags {
        fGenerateChildXrefs = 1<<8,
    };

    CGtfReader(
        unsigned int =0,
        const string& = "",
        const string& = "",
        SeqIdResolver = CReadUtil::AsSeqId,
        CReaderListener* = nullptr);

    CGtfReader(
        unsigned int,
        CReaderListener*);

    virtual ~CGtfReader();

    CRef< CSeq_annot >
    ReadSeqAnnot(
        ILineReader& lr,
        ILineErrorListener* pErrors=nullptr) override;

protected:
    void xProcessData(
        const TReaderData&,
        CSeq_annot&) override;

    CGff2Record* x_CreateRecord() override { return new CGtfReadRecord(); }

    bool xUpdateAnnotFeature(
        const CGff2Record&,
        CSeq_annot&,
        ILineErrorListener* =nullptr) override;

    virtual bool xUpdateAnnotCds(
        const CGtfReadRecord&,
        CSeq_annot&);

    virtual bool xUpdateAnnotTranscript(
        const CGtfReadRecord&,
        CSeq_annot&);

private:
    bool xUpdateAnnotParent(
        const CGtfReadRecord& record,
        const string& parentType,
        CSeq_annot& annot);

protected:
    void xPostProcessAnnot(
        CSeq_annot&) override;

    bool xCreateFeatureId(
        const CGtfReadRecord&,
        const string&,
        CSeq_feat&);

    bool xCreateParentGene(
        const CGtfReadRecord&,
        CSeq_annot&);

    bool xFeatureSetQualifiersGene(
        const CGtfReadRecord& record,
        CSeq_feat&);

    bool xFeatureSetQualifiersRna(
        const CGtfReadRecord& record,
        CSeq_feat&);

    bool xFeatureSetQualifiersCds(
        const CGtfReadRecord& record,
        CSeq_feat&);

private:
    bool xFeatureSetQualifiers(
        const CGtfReadRecord& record,
        const set<string>& ignoredAttrs,
        CSeq_feat&);

protected:    

    bool xCreateParentCds(
        const CGtfReadRecord&,
        CSeq_annot&);

    bool xCreateParentMrna(
        const CGtfReadRecord&,
        CSeq_annot&);

    bool xFeatureSetDataGene(
        const CGtfReadRecord&,
        CSeq_feat&);

    virtual bool xFeatureSetDataRna(
        const CGtfReadRecord&,
        CSeq_feat&,
        CSeqFeatData::ESubtype );

    bool xFeatureSetDataMrna(
        const CGtfReadRecord&,
        CSeq_feat&);

    bool xFeatureSetDataCds(
        const CGtfReadRecord&,
        CSeq_feat&);

    bool xFeatureTrimQualifiers(
        const CGtfReadRecord&,
        CSeq_feat&);
private:
    bool xFeatureTrimQualifiers(
        const CGtfAttributes& attributes,
        CSeq_feat&);

    bool xFeatureTrimQualifiers(
        const CGtfAttributes& prevAttributes,
        const CGtfAttributes& currentAttributes,
        CSeq_feat&);


    void xCheckForGeneIdConflict(
        const CGtfReadRecord& record);


    void xPropagateQualToParent(
            const CGtfReadRecord& record,
            const string& qualName,
            CSeq_feat& parent);


protected:
    CRef<CSeq_feat> xFindFeatById(
        const string&);

    bool xProcessQualifierSpecialCase(
        const string&,
        const CGtfAttributes::MultiValue&,
        CSeq_feat&);

    void xFeatureAddQualifiers(
        const string& key,
        const CGtfAttributes::MultiValue&,
        CSeq_feat&);

    void xSetAncestorXrefs(
        CSeq_feat&,
        CSeq_feat&) override;

    unique_ptr<CGtfLocationMerger> mpLocations;

private:
    using TChildQualMap = map<string, CGtfAttributes>;
    using TParentChildQualMap = map<string, TChildQualMap>;

    map<string, string> m_TranscriptToGeneMap;
    TParentChildQualMap m_ParentChildQualMap;
};

END_SCOPE(objects)
END_NCBI_SCOPE

#endif // OBJTOOLS_READERS___GTF_READER__HPP