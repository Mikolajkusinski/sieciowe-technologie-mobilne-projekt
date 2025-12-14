using System.Runtime.Serialization;

namespace SoapWebApi.Models;

// Explicitly set the model namespace so member elements (TopLeft/BottomRight/ImageData)
// are emitted/expected in the same namespace as other models (mirrors Pixel request)
[DataContract(Namespace = "http://schemas.datacontract.org/2004/07/SoapWebApi.Models")]
public class GeoMapRequest
{
    [DataMember] 
    public GeoCoordinates TopLeft { get; set; } = null!;

    [DataMember] 
    public GeoCoordinates BottomRight { get; set; } = null!;

    [DataMember]
    public byte[] ImageData { get; set; } = null!;
}